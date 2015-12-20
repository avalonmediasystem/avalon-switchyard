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

describe 'creation of media objects' do
  before :all do
    @media_object = MediaObject.new
  end
  describe 'parsing post requests' do
    it 'returns a list of mdpi barcodes' do
      codes_str = "18\n17\n19\n29\n20\n06"
      codes_arr = %w(18 17 19 29 20 06)
      expect(@media_object.parse_barcodes(codes_str)).to match(codes_arr)
    end

    it 'returns an empty list when no mdpi barcodes are found' do
      expect(@media_object.parse_barcodes(nil)).to match([])
    end

    it 'returns a hash of the request json' do
      str = '{"part_total":3,"group_name":"GR00034889","parts":[]}'
      expect(@media_object.parse_json(str).class).to eq(Hash)
    end

    it 'returns an empty hash when the json cannot be parsed' do
      expect(@media_object.parse_json(nil)).to eq({})
    end

    it 'can parse a full request body' do
      expect(@media_object.parse_request_body(load_sample_obj)[:barcodes]).not_to be_empty
      expect(@media_object.parse_request_body(load_sample_obj)[:json].keys).not_to be_empty
    end

    describe 'checking request validity' do
      before :all do
        # For these tests don't use a random fixture, since we want to break a known good one
        # Makes debugging easier if we ever accidentally load a bad fixture
        @fixture = 'GR00034889.txt'
      end
      it 'marks the status as valid when the request is valid' do
        expect(@media_object.parse_request_body(load_sample_obj(filename: @fixture))[:status]).to be_truthy
      end

      it 'marks the status as invalid when the request is not valid' do
        expect(@media_object.parse_request_body('foo')[:status][:valid]).to be_falsey
        expect(@media_object.parse_request_body('foo')[:status][:error].class).to eq(String)
        expect(@media_object.parse_request_body('foo')[:status][:error].size).not_to eq(0)
      end

      describe 'checking for omission of a specific piece of the request' do
        before :each do
          @valid_request = @media_object.parse_request_body(load_sample_obj(filename: @fixture))
        end

        it 'marks the status as invalid when there are no barcodes' do
          @valid_request[:barcodes] = []
          expect(@media_object.check_request(@valid_request)[:status][:valid]).to be_falsey
        end

        it 'marks the status as invalid when there is no json' do
          @valid_request[:json] = {}
          expect(@media_object.check_request(@valid_request)[:status][:valid]).to be_falsey
        end

        it 'marks the status as invalid when the group name is nil' do
          @valid_request[:json][:group_name] = nil
          expect(@media_object.check_request(@valid_request)[:status][:valid]).to be_falsey
        end

        it 'marks the status as invalid when the group name is an empty string' do
          @valid_request[:json][:group_name] = ''
          expect(@media_object.check_request(@valid_request)[:status][:valid]).to be_falsey
        end
      end
    end
  end
  describe 'registering and destroying an object' do
    before :all do
      @content = @media_object.parse_request_body(load_sample_obj)
    end

    it 'registers an object' do
      @media_object.destroy_object(@content[:json][:group_name])
      expect(MediaObject.find_by(group_name: @content[:json][:group_name])).to be_nil
      expect(@media_object.register_object(@content)).to be_truthy
      expect(MediaObject.find_by(group_name: @content[:json][:group_name])).not_to be_nil
    end

    it 'retries registering an object when there is an error' do
      allow(ActiveRecord::Base).to receive(:create).and_raise(ActiveRecord::ConnectionTimeoutError)
      expect(ActiveRecord::Base).to receive(:create).exactly(Sinatra::Application.settings.max_retries).times
      expect(@media_object.register_object(@content)[:success]).to be_falsey
    end

    it 'removes a previous entry when an object is retried' do
      expect(ActiveRecord::Base).to receive(:destroy_all).exactly(:once)
      expect(@media_object.register_object(@content)).to be_truthy
    end

    it 'retries destroying an object when there is an error' do
      allow(ActiveRecord::Base).to receive(:destroy_all).and_raise(ActiveRecord::ConnectionTimeoutError)
      expect(ActiveRecord::Base).to receive(:destroy_all).exactly(Sinatra::Application.settings.max_retries).times
      expect(@media_object.destroy_object(@content[:json][:group_name])[:success]).to be_falsey
    end

    it 'destroys an object' do
      @media_object.register_object(@content)
      expect(MediaObject.find_by(group_name: @content[:json][:group_name])).not_to be_nil
      expect(@media_object.destroy_object(@content[:json][:group_name])[:success]).to be_truthy
      expect(MediaObject.find_by(group_name: @content[:json][:group_name])).to be_nil
    end
  end
  describe 'displaying an object' do
    before :each do
      @object = @media_object.register_object(@media_object.parse_request_body(load_sample_obj))
    end

    after :each do
      @media_object.destroy_object(@object[:group_name])
    end

    it 'displays an object as json' do
      expect(@media_object.object_status_as_json(@object[:group_name]).class).to eq(Hash)
      expect(@media_object.object_status_as_json(@object[:group_name])[:error]).to be_nil
    end

    it 'returns 404 when the object is not found' do
      @media_object.destroy_object(@object[:group_name])
      expect(@media_object.object_status_as_json(@object[:group_name]).class).to eq(Hash)
      expect(@media_object.object_status_as_json(@object[:group_name])[:error]).to eq(404)
      expect(@media_object.object_status_as_json(@object[:group_name])[:success]).to be_falsey
    end

    it 'returns 500 when the databsase cannot be reached' do
      allow(ActiveRecord::Base).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)
      expect(@media_object.object_status_as_json(@object[:group_name]).class).to eq(Hash)
      expect(@media_object.object_status_as_json(@object[:group_name])[:error]).to eq(500)
      expect(@media_object.object_status_as_json(@object[:group_name])[:success]).to be_falsey
    end
  end
end