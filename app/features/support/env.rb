ENV['RACK_ENV'] = 'test'
require 'pry'
require 'rack/test'
require 'stringio'


module CinemaWorld
  include Rack::Test::Methods

  def root_directory
    Pathname.new(__FILE__).dirname.join("..","..","..","..","cinema-app")
  end



  def capture_stderr
    # The output stream must be an IO-like object. In this case we capture it in
    # an in-memory IO object so we can return the string value. You can assign any
    # IO object here.
    previous_stderr, $stderr = $stderr, StringIO.new
    yield
    $stderr.string
  ensure
    # Restore the previous value of stderr (typically equal to STDERR).
    $stderr = previous_stderr
  end


  def app
    # HACK: Late 'require', otherwise we can't test the initializers
    require File.expand_path '../../../app.rb', __FILE__
    ActiveCinema::App.set :environment, :test
    @app = Rack::Builder.new do
      run ActiveCinema::App
    end
  end
end

World(CinemaWorld)

After("@writes_configuration") do |scenario|
  config_file = root_directory.join("app", "config", "test.config.yml")
  FileUtils.rm(config_file)
end
