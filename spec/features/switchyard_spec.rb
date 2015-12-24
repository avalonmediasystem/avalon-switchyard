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
  before :all do
    @valid_token = ApiToken.new.create_token[:token]
  end

  before :each do
    MediaObject.destroy_all
  end

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

      it 'successfull authorizes creation of a media object when the token is valid' do
        post '/media_objects/create', 'foo', 'HTTP_API_TOKEN' => @valid_token
        expect(last_response.status).not_to eq(401)
      end

      describe 'failed post requests' do
        it 'halt with error code 400 if the request body is not valid' do
          post '/media_objects/create', 'foo', 'HTTP_API_TOKEN' => @valid_token
          expect(last_response.status).to eq(400)
        end

        it 'halts with error code 500 if the database cannot be accessed' do
          mo = MediaObject.new
          allow(MediaObject).to receive(:new).and_return(mo)
          allow(mo).to receive(:register_object).and_return(success: false, error: 404)
          post '/media_objects/create', load_sample_obj, 'HTTP_API_TOKEN' => @valid_token
          expect(last_response.status).to eq(500)
        end

        it 'halts with error code 200 if the object is not found immediately after registration' do
          mo = MediaObject.new
          allow(MediaObject).to receive(:new).and_return(mo)
          allow(mo).to receive(:object_status_as_json).and_return(success: false, error: 404)
          post '/media_objects/create', load_sample_obj, 'HTTP_API_TOKEN' => @valid_token
          expect(last_response.status).to eq(200)
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body).symbolize_keys
          expect(result[:error]).to be_truthy
          expect(result[:message]).not_to be_nil
        end

        it 'halts with error code 500 if the database times out while trying to get the object' do
          mo = MediaObject.new
          allow(MediaObject).to receive(:new).and_return(mo)
          allow(mo).to receive(:object_status_as_json).and_return(success: false, error: 500)
          post '/media_objects/create', load_sample_obj, 'HTTP_API_TOKEN' => @valid_token
          expect(last_response.status).to eq(500)
        end

        it 'posts a valid request and displays the result as json' do
          mo = MediaObject.new
          allow(MediaObject).to receive(:new).and_return(mo)
          allow(mo).to receive(:post_new_media_object).and_return('')
          post '/media_objects/create', load_sample_obj, 'HTTP_API_TOKEN' => @valid_token
          byebug
          expect(last_response.ok?).to be_truthy
          expect(last_response.status).to eq(200)
          result = JSON.parse(last_response.body).symbolize_keys
          expect(result[:group_name]).not_to be_nil
          expect(result[:status]).to eq('received')
          expect(result[:locked]).to be_falsey
          expect(result[:error]).to be_falsey
        end
      end
    end
  end
  describe 'queryinng for object status' do
    before :all do
      mo = MediaObject.new
      @inserted_object = mo.parse_request_body(load_sample_obj)
      mo.register_object(@inserted_object)
    end

    it 'requires authorization to get get' do
      get "/media_objects/status/whatever"
      expect(last_response.ok?).to be_falsey
      expect(last_response.status).to eq(401)
    end

    it 'displays the status of the object' do
      get "/media_objects/status/#{@inserted_object[:json][:group_name]}", nil, 'HTTP_API_TOKEN' => @valid_token
      response = JSON.parse(last_response.body).symbolize_keys
      expect(response.keys.size).to eq(11)
    end

    it 'returns 200 if the object is not found' do
      get '/media_objects/status/IndianaFootball', nil, 'HTTP_API_TOKEN' => @valid_token
      expect(last_response.ok?).to be_truthy
      expect(last_response.status).to eq(200)
      result = JSON.parse(last_response.body).symbolize_keys
      expect(result[:error]).to be_truthy
      expect(result[:message]).not_to be_nil
    end

    it 'returns 500 if the database is unavailable' do
      mo = MediaObject.new
      allow(MediaObject).to receive(:new).and_return(mo)
      allow(mo).to receive(:object_status_as_json).and_return(success: false, error: 500)
      get "/media_objects/status/#{@inserted_object[:json][:group_name]}", nil, 'HTTP_API_TOKEN' => @valid_token
      expect(last_response.ok?).to be_falsey
      expect(last_response.status).to eq(500)
    end
  end
end
