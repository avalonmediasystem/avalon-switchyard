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

#ruby '2.1.7'
source 'https://rubygems.org'

# :default group gems
gem 'dotenv'
gem 'edtf'
gem 'nokogiri'
gem 'rake'
gem 'rest-client'
gem 'retries'
gem 'sinatra'
gem 'sinatra-activerecord'
gem 'whenever', require: false

group :development do
  gem 'byebug'
  gem 'capistrano', '>3.1.2'
  gem 'capistrano-bundler'
  gem 'capistrano-passenger', require: false
  gem 'highline'
  gem 'rubocop'
end

group :test do
  gem 'capybara'
  gem 'coveralls', require: false
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'webmock'
end

group :development, :test do
  gem 'rb-readline'
  gem 'sqlite3'
end

group :production, optional: true do
  gem 'mysql2'
end
