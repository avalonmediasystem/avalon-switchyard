| Service | Status|
--- | --- |
| Travis-CI | [![Build Status](https://travis-ci.org/avalonmediasystem/avalon-switchyard.svg)](https://travis-ci.org/avalonmediasystem/avalon-switchyard)
| Coveralls.io Master Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=master)
| Coveralls.io Develop Branch | [![Coverage Status](https://coveralls.io/repos/avalonmediasystem/avalon-switchyard/badge.svg?branch=master&service=github)](https://coveralls.io/github/avalonmediasystem/avalon-switchyard?branch=develop)

#Avalon Switchyard

## About

Avalon Switchyard is a Sinatra Ruby application written to route content between multiple instances of the Avalon Media System within the same institution.  Switchyard is designed to receive JSON data from an external source, such as a digitization lab, and then determine the proper Avalon instance to create the media object in.  Avalon Switchyard will then generate the proper API call to post the media object to the selected Avalon instance.  If necessary it will also create a collection to contain the media object.


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

IU folks see internal wiki for institution specifics.

Switchyard is configured to deployed as a Rack application using Capistrano currently.  You will need to make changes to `config.ru` and `config/deploy.rb` as required by your production environment.  Currently Switchyard will attempt to install itself to `/var/www/switchyard`.  A Capistrano deploy can be executed via `bundle exec cap production deploy`.

## Authorizing Services to Use Avalon Switchyard

Any JSON posted to Avalon Switchyard must be accompanied by a valid API Token in the header.

* _create an API Token_: run `RACK_ENV=ENV bundle exec rake tokens:create_token ` from the root dir of Avalon Switchyard
* _deauthorize an API Token_: run `RACK_ENV=ENV bundle exec rake tokens:decomission_token['token']` from the root dir of Avalon Switchyard

For additional documentation see the `Rakefile` and the `api_token.rb` model.

## Interacting with Avalon Switchyard

Avalon Switchyard currently has the following working routes.  These are:

* `get /` to view the status of the app
* `post /media_objects/create` to create an object
* `get /media_objects/status/:group_name` to get information on a created object

#### get /

No authorization is required.  This request returns an http status of 200 and information on the app in json, assuming the app is online and functional

### post /media_objects/create

This route requires authorization to be submitted in the header using the param `api_token`.  See _Authorizing Services to Use Avalon Switchyard_ for information on generating a valid token.  To post to this route use the style of:

`post /media_objects/create, content, api_token: token`

For specifics on how to format the content as json, see `spec/fixtures/sample_objects`.  Each file in that directory is an example of valid sample content formatted as JSON.  

### get /media_objects/status/:group_name

This route requires authorization to be submitted in the header using the param `api_token`.  See _Authorizing Services to Use Avalon Switchyard_ for information on generating a valid token.  To get data from this route use the style of:

`get /media_objects/status/:group_name, nil, api_token: token`

## Responses and Codes for media_objects

All media_objects functions respond in the same manner.  Their responses are:

* Not authorized
  - HTTP Code: 401
  - Response Body: 'Not authorized'
* Internal Server Error
  - HTTP Code: 500
  - Response Body: json in the form of: `{error: true, message: STRING}`
  - Response Body may also be the generic Sinatra 500 page if an unhandled error occurred
* Successful Action
  - HTTP Code: 200
  - Response Body: json of the object in the form of: `{key: value}`  Keys are:
    * 'group_name': STRING the group_name of the object (user submitted)
    * 'status': STRING the status of the object, options are:
      - 'received': object has been received but no attempts have been made to place it in an Avalon instance
      - 'deposited': object has been placed into an Avalon instance
      - 'failed': object could not be deposited for some reason
    * 'error': BOOLEAN true if an error has occurred (status should be failed), false if no error has yet occurred
    * 'error_message': information about the error
    * 'created': STRING time the record was created, timezone: UTC, format: ISO8601
    * 'last_modified': STRING time the record was last updated, timezone: UTC, format: ISO8601
    * 'avalon_chosen': STRING uri of the Avalon instance selected for deposition (note this does not mean deposited, check error and status)
    * 'avalon_pid': STRING the object's pid in the selected Avalon, implies successful deposition
    * 'avalon_url': URL to the object in an Avalon, implies successful deposition
    * 'locked': BOOLEAN A Switchyard batch processed has locked the object for some reason and it cannot be updated, resubmission of the object though will cause deletion even if locked is true
* Invalid Data Posted for Creation
  - This applies only to `post /media_objects/create, content, api_token: token`
  - HTTP Code: 400
  - Response Body: json in the form of `{ status: '400', error: true, message: STRING}`

For further information routes see `switchyard.rb` and for media_object values see `lib/objects.rb`
