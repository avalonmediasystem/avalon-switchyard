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

require 'spec_helper'
require 'json'

describe 'Switchyard API Functionality' do
  describe 'Status and Configuration Refresh' do
    it 'returns information about the app at /' do
      get '/'
      expect(last_response.ok?).to be_truthy
      expect(JSON.parse(last_response.body).class).to eq(Hash)
    end
  end
  describe 'Creating Media Objects' do
    describe 'authorization' do
      it 'requires authorization to create a media object' do
        post '/media_objects/create'
        expect(last_response.ok?).to be_falsey
        expect(last_response.status).to eq(401)
      end
    end
  end
end
