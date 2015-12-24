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
require 'webmock'

describe 'creation of media objects' do
  before :all do
    @media_object = MediaObject.new
  end
  describe 'parsing post requests' do
    it 'returns a hash of the request json' do
      str = '{"part_total":3,"group_name":"GR00034889","parts":[]}'
      expect(@media_object.parse_json(str).class).to eq(Hash)
    end

    it 'returns an empty hash when the json cannot be parsed' do
      expect(@media_object.parse_json(nil)).to eq({})
    end

    it 'can parse a full request body' do
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

    it 'returns 404 and a message when the object is not found' do
      @media_object.destroy_object(@object[:group_name])
      expect(@media_object.object_status_as_json(@object[:group_name]).class).to eq(Hash)
      expect(@media_object.object_status_as_json(@object[:group_name])[:error]).to eq(404)
      expect(@media_object.object_status_as_json(@object[:group_name])[:success]).to be_falsey
      expect(@media_object.object_status_as_json(@object[:group_name])[:message]).not_to be_nil
    end

    it 'returns 500 when the databsase cannot be reached' do
      allow(ActiveRecord::Base).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)
      expect(@media_object.object_status_as_json(@object[:group_name]).class).to eq(Hash)
      expect(@media_object.object_status_as_json(@object[:group_name])[:error]).to eq(500)
      expect(@media_object.object_status_as_json(@object[:group_name])[:success]).to be_falsey
    end
  end

  describe 'updating an object' do
    it 'updates an object' do
      first_obj = @media_object.register_object(@media_object.parse_request_body(load_sample_obj))
      second_obj = first_obj
      loop do
        second_obj = @media_object.register_object(@media_object.parse_request_body(load_sample_obj))
        break if second_obj[:group_name] != first_obj[:group_name] # Make sure we load two different fixtures
      end
      second_object_json = @media_object.object_status_as_json(second_obj[:group_name]).symbolize_keys
      @media_object.update_status(second_obj[:group_name], {group_name: 'junk'})
      @media_object.update_status(first_obj[:group_name], second_object_json.except(:id, :group_name))
      expect(@media_object.object_status_as_json(first_obj[:group_name]).symbolize_keys.except(:id, :group_name)).to match(second_object_json.except(:id, :group_name))
    end
  end

  describe 'transforming posting an object' do
    before :all do
      @registrable = @media_object.parse_request_body(load_sample_obj)
      @object = @registrable[:json]
    end

    describe 'parsing file information for an object' do
      it 'can transform the object' do
        allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
        #byebug
        transform = @media_object.transform_object(@object)
        expect(transform.class).to eq(String)
        expect(JSON.parse(transform)['fields'].class).to eq(Hash)
        expect(JSON.parse(transform)['files'].class).to eq(Array)
      end

      describe 'getting the file structure' do
        before :all do
          #byebug
          @media_object.register_object(@registrable)
          @file_info = @object[:parts][0]['files']['1']
        end
        it 'returns the file structure for a file' do
          expect(@media_object.file_structure_as_xml(Hash.from_xml(@file_info['structure'])['Item'], @object).class).to eq(String)
        end

        it 'writes an error when the file structure cannot be parsed' do
          expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
          @media_object.file_structure_as_xml({} , {})
        end

        describe 'parsing file info' do
          it 'can parse info for one file in an object' do
            expect(@media_object.get_file_info(@object, @file_info).class).to eq(Hash)
          end

          # Turn this back on once file parsing has been finalized
          xit 'writes an error when the file cannot be parsed' do
            expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
            @media_object.get_file_info(@object, @file_info)
          end

          describe do
            it 'can parse all files in an object' do
              parse = @media_object.get_all_file_info(@object)
              expect(parse.class).to eq(Array)
              expect(parse[0].class).to eq(Hash)
            end
          end
        end
      end

      describe 'getting the file format' do
        it 'can get the file format' do
          expect(@media_object.get_file_format(@object).class).to eq(String)
        end

        it 'writes an error when the file format cannot be retrieved' do
          expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
          expect(@media_object).to receive(:parse_mods).and_return(nil)
          @media_object.get_file_format(@object)
        end
      end
    end

    describe 'obtaining field information for an object' do
      describe 'parsing mods' do
        it 'it can parse the mods' do
          expect(@media_object.parse_mods(@object).class).to eq(Hash)
        end

        it 'writes an error when the mods cannot be parsed' do
          expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
          @media_object.parse_mods({})
        end
      end

      describe 'getting the collection name' do
        it 'can get the collection name' do
          expect(@media_object.get_collection_name(@object).class).to eq(String)
        end

        it 'writes an error when the collection name cannot be obtained' do
          expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
          @media_object.get_collection_name({})
        end
      end

      describe 'getting required fields for an object' do
        it 'gets the mandatory fields for an object' do
          fields = @media_object.get_fields_from_mods(@object)
          [:title, :creator, :date_issued, :date_created].each do |field|
            expect(fields.keys.include? field).to be_truthy
            expect(fields[field]).not_to be_nil
          end
        end
      end

      describe 'routing an object and determining collection' do
        it 'can route the object' do
          expect(@media_object.attempt_to_route(@object).class).to eq(Hash)
        end

        # This doesn't work right now since we have no routing intelligence and just always assume default
        xit 'writes an error when the object cannot be routed' do
          expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
          @media_object.attempt_to_route({})
        end

        it 'can determine the collection of an object' do
          collection = Collection.new
          allow(Collection).to receive(:new).and_return(collection)
          allow(collection).to receive(:get_or_create_collection_pid).and_return('foo')
          expect(@media_object.get_object_collection_id(@object, 'target')).to eq('foo')
        end

        it 'can writes an error if it cannot get the collection pid' do
          collection = Collection.new
          allow(Collection).to receive(:new).and_return(collection)
          allow(collection).to receive(:get_or_create_collection_pid).and_return(nil)
          expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
          @media_object.get_object_collection_id(@object, 'target')
        end
      end
    end
  end

  describe 'recording errors' do
    it 'writes an error to the database' do
      content = @media_object.parse_request_body(load_sample_obj)
      @media_object.destroy_object(content[:json][:group_name])
      @media_object.register_object(content)
      expect(@media_object.object_status_as_json(content[:json][:group_name])['error']).to be_falsey
      expect{@media_object.object_error_and_exit(content[:json], 'test error')}.to raise_error
    end
  end

  describe 'posting media objects' do
    before :all do
      o = @media_object.parse_request_body(load_sample_obj(filename: @fixture))
      @media_object.register_object(o)
      @object = o[:json]
    end

    it 'properly forms a post request for an object' do
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      stub_request(:post, "https://youravalon.edu/media_objects.json").to_return(body: {id: 'pid'}.to_json, status: 200)
      @media_object.post_new_media_object(@object)
      results = @media_object.object_status_as_json(@object[:group_name])
      expect(results['status']).to eq('submitted')
      expect(results['error']).to be_falsey
      expect(results['avalon_pid']).to eq('pid')
      expect(results['avalon_chosen']).to eq(Router.new.select_avalon(@object)[:url])
    end

    it 'writes an error when the post request fails' do
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      stub_request(:post, "https://youravalon.edu/media_objects.json").to_return(body: {error: 'unh-oh'}.to_json, status: 500)
      expect{@media_object.post_new_media_object(@object)}.to raise_error
    end
  end
end
