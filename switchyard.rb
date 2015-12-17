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

require 'sinatra'
require 'json'
require 'logger'
require 'switchyard_configuration'
require 'sinatra/activerecord'
require 'byebug'

# All items set are accessible as settings.key
# @example
#   settings.app_start_time #=> "2015-12-17T19:02:05Z"
configure do
  set :app_start_time, Time.now.utc.iso8601
  loader = SwitchyardConfiguration.new

  # db_settings = loader.load_yaml('database.yml')[Sinatra::Application.environment.to_s]
  # set :database, ActiveRecord::Base.establish_connection(
  #   adapter: db_settings['adapter'],
  #   # :host     => db.host,
  #   # :username => db.user,
  #   # :password => db.password,
  #   database: db_settings['database'],
  #   encoding: db_settings['encoding'],
  #   pool: db_settings['pool'],
  #   timeout: db_settings['timeout']
  # )
  set :switchyard_configs, loader.load_yaml('switchyard.yml')
  byebug
  # Sinatra::Application.environment
end

get '/' do
  'Switchyard'
end

# TODO:  Implement retries
post '/media_objects/create' do
  # 'Create a media object'
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
