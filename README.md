| Service | Status|
--- | --- |
| Travis-CI | [![Build Status](https://travis-ci.org/avalonmediasystem/avalon-switchyard.svg)](https://travis-ci.org/avalonmediasystem/avalon-switchyard)
| Coveralls.io Master Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=master)
| Coveralls.io Develop Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=develop)

#Avalon Switchyard

### About

Avalon Switchyard is a Sinatra Ruby application written to route content between multiple instances of the Avalon Media System.  

## Installing Avalon Switchyard for Development

1.  Clone this git repo and navigate to its root
1.  `cp config/database.example.yml config/database.yml`
1.  `bundle install`
1.  `rake db:create`
1.  `ruby switchyard.rb`
1.  Open a browser and navigate to `http://localhost:4567/`
