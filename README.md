| Service | Status|
--- | --- |
| Travis-CI | [![Build Status](https://travis-ci.org/avalonmediasystem/avalon-switchyard.svg)](https://travis-ci.org/avalonmediasystem/avalon-switchyard)
| Coveralls.io Master Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=master)
| Coveralls.io Develop Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=develop)

#Avalon Switchyard

## About

Avalon Switchyard is a Sinatra Ruby application written to route content between multiple instances of the Avalon Media System.  Switchyard is designed to receive JSON data from an external source, such as a digitization lab, and then determine the proper Avalon instance to create the media object in.


## Installing Avalon Switchyard for Development

1.  Clone this git repo and navigate to its root
1.  `rake setup:configs`
1.  `bundle install`
1.  `rake db:migrate`
1.  `ruby switchyard.rb`
1.  Open a browser and navigate to `http://localhost:4567/`
1.  Alternative `bundle exec rspec` should pass all tests

## Deploying Avalon Switchyard

TODO

## Authorizing Services to Use Avalon Switchyard

Any JSON posted to Avalon Switchyard must be accompanied by a valid API Token in the header.

_create an API Token_ run `rake tokens:create_token` from the root dir of Switchyard
_deauthorize an API Token_ run `rake tokens:decomission_token['token']` from the door dir of Switchyard
