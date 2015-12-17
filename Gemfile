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

source 'https://rubygems.org'

# :default group gems
gem 'retries'
gem 'sinatra'
gem 'sinatra-activerecord'
gem 'rake'
gem 'coveralls', require: false
# gem 'activerecord', '~> 4.2', '>= 4.2.5'
# gem 'rake'

group :development do
  gem 'byebug'
  gem 'capistrano', '>3.1.2'
  gem 'capistrano-bundler'
  gem 'highline'
end

group :test do
  gem 'capybara'
  gem 'rspec'
end

group :development, :test do
  gem 'sqlite3'
end
