def create_config_file(string)
  config_file = root_directory.join("app", "config","test.config.yml")
  File.open(config_file, File::WRONLY|File::CREAT|File::EXCL) do |file|
    file.write string
  end
end

Given(/^I have this config\.yml$/) do |string|
  create_config_file(string)
end

Given(/^I have an empty config\.yml$/) do
  create_config_file("")
end


Given(/^there is no file in '(.+)'$/) do |path|
  file = root_directory.join(path)
  expect(File).not_to exist(file)
end

When(/^I try to start the server$/) do
  @error_message = capture_stderr do
    begin
      app
    rescue SystemExit
      # ignore
    end
  end
end


When(/^I start the server$/) do
  app
end

Then(/^I should see an error message on the command line like this:$/) do |string|
  expect(@error_message).to include(string)
end
