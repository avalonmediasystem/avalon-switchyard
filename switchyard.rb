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
require 'objects'
require 'router'
require 'collection'
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
  set :max_retries, 5
  set :max_sleep_seconds, 5
  set :max_sleep_seconds, 0.2 unless settings.production?
  loader = SwitchyardConfiguration.new
  set :switchyard_configs, loader.load_yaml('switchyard.yml')
  Dir.mkdir('log') unless Dir.exist?('log')
  set :switchyard_log, Logger.new("log/#{ENV['RACK_ENV']}.log")
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

  def database_connection_failure!
    halt 500, { error: true, message: 'Could not connect to database' }.to_json
  end

  def record_not_found!
    halt 200, { error: true, message: 'Record not found' }.to_json
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


post '/media_objects/create' do
  content_type :json
  protected!
  media_object = Objects.new
  # Parse the request and throw a 400 code if bad data was posted in
  posted_content = request.body.read
  settings.switchyard_log.info "Recieved request #{posted_content}"
  object = media_object.parse_request_body(posted_content)
  settings.switchyard_log.info "Parsed #{object}"
  halt 400, { status: '400', error: true, message: object[:status][:error] }.to_json unless object[:status][:valid] # halt if the provided data is incorrect
  already_present = media_object.already_exists_in_avalon?(object)
  registration_results = media_object.register_object(object)
  database_connection_failure! unless registration_results[:success]

  # Display the object as it is currently entered into the database
  status = media_object.object_status_as_json(registration_results[:group_name])
  unless status[:success]
    database_connection_failure! if status[:error] == 500
    record_not_found! if status[:error] == 404
  end
  stream do |out|
    out << status.to_json # return the initial status so MDPI has some response and then keep working
    begin
      media_object.post_new_media_object(object) unless already_present
      media_object.update_media_object(object) if already_present
    rescue Exception => e
      message = "Failed to send object #{object} to Avalon, exited wit exception #{e}"
      settings.switchyard_log.error message
      settings.switchyard_log.error e.backtrace.join("\n")
      media_object.object_error_and_exit(object, message)
    end
  end

end

get '/media_objects/status/:group_name' do
  content_type :json
  protected!
  media_object = Objects.new
  status = media_object.object_status_as_json(params[:group_name])
  unless status[:success]
    database_connection_failure! if status[:error] == 500
    record_not_found! if status[:error] == 404
  end
  status.to_json
end
