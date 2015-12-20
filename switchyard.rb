# Copyright 2011-2015, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

$LOAD_PATH << File.expand_path('../', __FILE__)
$LOAD_PATH << File.expand_path('../', __FILE__) + '/lib/'
$LOAD_PATH << File.expand_path('../', __FILE__) + '/models/'

require 'sinatra'
require 'json'
require 'logger'
require 'switchyard_configuration'
require 'api_token'
require 'media_object'
require 'sinatra/activerecord'
require 'byebug' if settings.development?

# automatically load config/database.yml and assing it to settings.datase:
register Sinatra::ActiveRecordExtension

configure do
  # Anything set here is available at this level with settings.foo
  # @example
  #   settings.app_start_time #=> "2015-12-17T19:02:05Z"
  # In libraries these settings can be accessed as Sinatra::Application.settings.foo
  # @example
  #   Sinatra::Application.settings.app_start_time #=> "2015-12-17T19:02:05Z"
  set :app_start_time, Time.now.utc.iso8601
  loader = SwitchyardConfiguration.new
  set :switchyard_configs, loader.load_yaml('switchyard.yml')
  # ApiTokens.new.create_token('foo')
end

helpers do
  # Function to place on any route that desire to have protected by the Api token,
  # displays a 401 if the token is not valid
  #
  # @return [Nil] Returns nothing if the token is valid, allowing the request to continue
  def protected!
    return if ApiToken.new.valid_token?(env['HTTP_API_TOKEN'])
    halt 401, "Not authorized\n"
  end
end

# Displays status information about the app
#
# @return [JSON] A JSON has of the status params
get '/' do
  content_type :json
  { app_start_time: settings.app_start_time,
    rack_env: Sinatra::Application.environment
  }.to_json
end

# TODO:  Implement retries
post '/media_objects/create' do
  protected!
  media_object = MediaObject.new
  object = media_object.parse_request_body(request.body.read)
  halt 400, object[:status][:errors] unless object[:status][:valid] # halt if the provided data is incorrect
  #media_object.check_object(object)
  # object = JSON.parse(request.body)
end

get '/media_objects/status/:pid' do
  'Get a media object status'
end

# TODO: Make sure that Brian will want to create collections?
post '/collections/create' do
  'Create a collection'
end

# TODO: Make sure that Brian will want to get status on collections
get '/collections/status/:pid' do
  'Get a collection object status'
end
