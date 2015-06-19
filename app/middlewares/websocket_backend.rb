require 'faye/websocket'
require 'thread'
require 'json'
require 'erb'
require 'pry'

module ActiveCinema
  class WebsocketBackend
    KEEPALIVE_TIME = 15 # in seconds

    def initialize(app)
      @app              = app
      @voting_clients   = []
      @movie_clients    = []
      @votes            = Hash.new(0)
      @decision_active  = false
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env, nil, ping: KEEPALIVE_TIME)
        @video = ActiveCinema.the_video

        ws.on :open do
          p [:open, ws.object_id]
          case ws.url.split('/').last
          when 'voting'
            send_current_video(ws, @video, @decision_active)
            @voting_clients << ws
          when 'movie'
            @movie_clients << ws
            @decision_active  = false
            @video = ActiveCinema.set_current(ActiveCinema.start_video)
            send_next_video(@video, @votes)
          else
            add_all(ws)
          end
        end

        ws.on :message do |event|
          p [:message, event.data]
          json = JSON.parse(event.data)
          if json['decided']
            @votes[json['decided']] += 1
          elsif json['decision_active'] == true
            @decision_active = true
            send_all(event.data)
          elsif json['video'] == 'start'
            @video = ActiveCinema.start_video
            ActiveCinema.set_current(@video)
            send_next_video(@video, @votes)
          elsif json['video'] == 'ended'
            p [:votes, @votes]
            if !@votes.nil? && !@votes.empty? # TODO check for index
              @video = @video.sequels[random_max(@votes)]
              send_next_video(@video, @votes)
              @votes = Hash.new(0)
            elsif @video.sequels
              @video = @video.sequels.sample
              send_next_video(@video, @votes)
            else
              the_end
            end
            @decision_active = false
            ActiveCinema.set_current(@video) # Set global video to current video
          else
            the_end
          end
        end

        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]
          @movie_clients.delete(ws) if @movie_clients.include?(ws)
          @voting_clients.delete(ws) if @voting_clients.include?(ws)
          ws = nil
        end

        # Return async Rack response
        ws.rack_response

      else
        @app.call(env)
      end
    end

    private

    def random_max(votes)
      votes.group_by { |_, v| v }.max.last.sample.first
    end

    def sanitize(message)
      json = JSON.parse(message)
      json.each { |key, value| json[key] = ERB::Util.html_escape(value) }
      JSON.generate(json)
    end

    def add_all(ws)
      @movie_clients << ws
      @voting_clients << ws
    end

    def send_all(data)
      @voting_clients.each { |client| client.send(data) }
      @movie_clients.each { |client| client.send(data) }
    end

    def send_current_video(ws, video, decision_active)
      ws.send(JSON.generate(
                question: video.question,
                answers: video.answers,
                decision_active: decision_active))
    end

    def send_next_video(video, votes)
      @movie_clients.each do |client|
        client.send(
          JSON.generate(
            video: video.stream,
            question: video.question))
      end
      @voting_clients.each do |client|
        client.send(
          JSON.generate(
            question: video.question,
            answers: video.answers,
            votes: JSON.generate(votes)))
      end
    end

    def the_end
      send_all(JSON.generate(the_end: true))
    end
  end
end
