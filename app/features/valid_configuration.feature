Feature: Validate configuration file and give helpful error messages
As a movie producer who wants to change the structure of the interactive movie
I want to see friendly error messages if my configuration file is invalid
So I know immediately what I've done wrong and I can fix it


  @writes_configuration
  Scenario:
    Given I have an empty config.yml
    When I try to start the server
    Then I should see an error message on the command line like this:
    """
    Configuration file is invalid: Please add a key 'video'.
    """
