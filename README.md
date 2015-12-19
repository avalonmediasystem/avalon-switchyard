| Service | Status|
--- | --- |
| Travis-CI | [![Build Status](https://travis-ci.org/avalonmediasystem/avalon-switchyard.svg)](https://travis-ci.org/avalonmediasystem/avalon-switchyard)
| Coveralls.io Master Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=master)
| Coveralls.io Develop Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=develop)

#Avalon Switchyard

## About

Avalon Switchyard is a Sinatra Ruby application written to route content between multiple instances of the Avalon Media System.  Switchyard is designed to receive JSON data from an external source, such as a digitization lab, and then determine the proper Avalon instance to create the media object in.  Avalon Switchyard will then generate the proper API call to post the media object.  If necessary it will also create a collection to contain the media object.


## Installing Avalon Switchyard for Development

1.  Clone this git repo and navigate to its root
1.  `bundle install`
1.  `rake setup:configs`
1.  `rake db:migrate`
1.  `ruby switchyard.rb`
1.  Open a browser and navigate to `http://localhost:4567/`
1.  Alternatively `bundle exec rspec` should pass all tests

## Development Console

To launch a debug console navigate to the root of Avalon Switchyard and run:

1. `irb`
1. `require './switchyard.rb'`

Alternatively you can add in byebug where desired throughout the application.  When debugging via either method you can reach application settings thought `Sinatra::Application.settings`.  See the `configure` block of `switchyard.rb` for further documentation.


## Deploying Avalon Switchyard

TODO, IU folks see internal wiki

## Authorizing Services to Use Avalon Switchyard

Any JSON posted to Avalon Switchyard must be accompanied by a valid API Token in the header.

* _create an API Token_: run `RACK_ENV=ENV bundle exec rake tokens:create_token ` from the root dir of Avalon Switchyard
* _deauthorize an API Token_: run `RACK_ENV=ENV bundle exec rake tokens:decomission_token['token']` from the door dir of Avalon Switchyard

For additional documentation see the `Rakefile` and the `api_token.rb` model.
