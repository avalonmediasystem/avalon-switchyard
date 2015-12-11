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

require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'logger'

require 'sinatra/config_file'

config_file 'config/switchyard.yml'

get '/' do
  'Switchyard Route'
end

get '/switchyard/status' do
  'Switchyard Status is working fine'
end

get '/switchyard/reload_configs' do
  'Reload the config files'
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
