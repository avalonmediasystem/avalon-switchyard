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

require 'coveralls'
Coveralls.wear!
require 'rack/test'
require 'rspec'
require 'sinatra'
require File.expand_path '../../switchyard.rb', __FILE__
require 'pathname'
require 'sinatra/activerecord'
require 'restclient'
require 'webmock/rspec'

# Switchyard Specific Requires
require 'switchyard_configuration'
require 'api_token'
require 'media_object'
require 'router'
require 'collection'

ENV['RACK_ENV'] = 'test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

module RSpecMixin
  include Rack::Test::Methods
  def app() Sinatra::Application end
end

RSpec.configure { |c| c.include RSpecMixin }

# Loads a sample object fixture
# Grabs a random one if the file is not specified
def load_sample_obj(filename: nil)
  # path to sample objects
  p = './spec/fixtures/sample_objects/'
  p << filename unless filename.nil?
  file_list = Dir[p + '*.txt']
  p = file_list[rand(0..file_list.size - 1)] if filename.nil?
  File.read(p)
end

def post_media_create_request(api_token: '', body: '')
  RestClient.post('http://localhost:4567', body, api_token: api_token)
end
