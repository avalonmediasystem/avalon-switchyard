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
    @media_object = Objects.new(posted_content: load_sample_obj)
  end
  describe 'parsing post requests' do
    it 'returns a hash of the request json' do
      str = '{"part_total":3,"group_name":"GR00034889","parts":[]}'
      obj = Objects.new(posted_content: str)
      expect(obj.parse_json.class).to eq(Hash)
    end

    it 'returns an empty hash when the json cannot be parsed' do
      obj = Objects.new
      expect(obj.parse_json).to eq({})
    end

    it 'can parse a full request body' do
      expect(@media_object.parse_request_body[:json].keys).not_to be_empty
    end

    describe 'checking request validity' do
      before :all do
        # For these tests don't use a random fixture, since we want to break a known good one
        # Makes debugging easier if we ever accidentally load a bad fixture
        @fixture = 'GR00034889.txt'
      end
      it 'marks the status as valid when the request is valid' do
        obj = Objects.new(posted_content: load_sample_obj(filename: @fixture))
        expect(obj.parse_request_body[:status]).to be_truthy
      end

      it 'marks the status as invalid when the request is not valid' do
        obj = Objects.new(posted_content: 'invalid_content')
        expect(obj.parse_request_body[:status][:valid]).to be_falsey
        expect(obj.parse_request_body[:status][:error].class).to eq(String)
        expect(obj.parse_request_body[:status][:error].size).not_to eq(0)
      end

      describe 'checking for omission of a specific piece of the request' do
        before :each do
          @media_object = Objects.new(posted_content: load_sample_obj(filename: @fixture))
          @valid_request = @media_object.parse_request_body
        end

        it 'marks the status as invalid when there is no json' do
          @media_object.instance_variable_set(:@object_hash, {json: {}})
          expect(@media_object.check_request[:status][:valid]).to be_falsey
        end

        it 'marks the status as invalid when the group name is nil' do
          @media_object.instance_variable_set(:@object_hash, {json: {group_name: nil}})
          expect(@media_object.check_request[:status][:valid]).to be_falsey
        end

        it 'marks the status as invalid when the group name is an empty string' do
          @media_object.instance_variable_set(:@object_hash, {json: {group_name: ''}})
          expect(@media_object.check_request[:status][:valid]).to be_falsey
        end
      end
    end
  end
  describe 'registering and destroying an object' do
    before :all do
      @content = @media_object.parse_request_body
    end

    it 'registers an object' do
      MediaObject.destroy_by(group_name: @content[:json][:group_name])
      expect(MediaObject.find_by(group_name: @content[:json][:group_name])).to be_nil
      expect(@media_object.register_object(@content)).to be_truthy
      expect(MediaObject.find_by(group_name: @content[:json][:group_name])).not_to be_nil
    end

    it 'retries registering an object when there is an error' do
      MediaObject.destroy_by(group_name: @content[:json][:group_name])
      allow(ActiveRecord::Base).to receive(:create).and_raise(ActiveRecord::ConnectionTimeoutError)
      expect(ActiveRecord::Base).to receive(:create).exactly(Sinatra::Application.settings.max_retries).times
      expect(@media_object.register_object(@content)[:success]).to be_falsey
    end

    it 'updates a previous entry when an object is retried' do
      @media_object.register_object(@content) #register object so it is present
      expect(@media_object).to receive(:update_status).exactly(:once)
      expect(@media_object.register_object(@content)).to be_truthy #run it again
    end

    it 'saves the object hash' do
        @media_object.register_object(@content) #register object so it is present
        expect(MediaObject.where(group_name: @content[:json][:group_name]).first.api_hash).not_to be_nil
    end

    it 'retries destroying an object when there is an error' do
      allow(MediaObject).to receive(:destroy_by).and_raise(ActiveRecord::ConnectionTimeoutError)
      expect(MediaObject).to receive(:destroy_by).exactly(Sinatra::Application.settings.max_retries).times
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
      @object = @media_object.register_object(@media_object.parse_request_body)
    end

    after :each do
      @media_object.destroy_object(@object[:group_name])
    end

    it 'displays an object as json' do
      expect(@media_object.object_status_as_json(@object[:group_name]).class).to eq(Hash)
      expect(@media_object.object_status_as_json(@object[:group_name])[:error]).to be_nil
    end

    it 'returns 404 and a message when the object is not found' do
      MediaObject.destroy_by(group_name: @object[:group_name])
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
    xit 'updates an object' do
      first_obj = Objects.new(load_sample_obj).parse

      first_obj = @media_object.register_object(first_obj.parse_request_body)
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
      @registrable = @media_object.parse_request_body
      @object = @registrable
    end

    describe 'parsing file information for an object' do
      it 'can transform the object' do
        allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
        transform = @media_object.transform_object(@object)
        expect(transform.class).to eq(String)
        expect(JSON.parse(transform)['fields'].class).to eq(Hash)
        expect(JSON.parse(transform)['files'].class).to eq(Array)
      end

      describe 'getting the file structure' do
        before :all do
          @media_object.register_object(@registrable)
          @file_info = @object[:json][:parts][0]['files']['1']
        end

        describe 'parsing file info' do
          it 'can parse info for one file in an object' do
            expect(@media_object.get_file_info(@object, @file_info,@object[:json][:parts][0]['mdpi_barcode'],{}).class).to eq(Hash)
          end

          # Turn this back on once file parsing has been finalized
          xit 'writes an error when the file cannot be parsed' do
            expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
            @media_object.get_file_info(@object, @file_info, {})
          end

          describe do
            it 'can parse all files in an object' do
              parse = @media_object.get_all_file_info(@object, {})
              expect(parse.class).to eq(Array)
              expect(parse[0].class).to eq(Hash)
            end
          end

          describe 'checking specific fixtures' do
            it 'returns correctly parsed file info' do
              obj= Objects.new(posted_content: load_sample_obj(filename: 'GR00104460.txt'))
              @sobject = obj.parse_request_body
              @file_info = @sobject[:json][:parts][0]['files']['1']
              @comments = obj.parse_comments(@sobject)
              @parsed_info = obj.get_file_info(@sobject, @file_info, @sobject[:json][:parts][0]['mdpi_barcode'], @comments)

              @fixture_info = {
                workflow_name: "avalon",
                percent_complete: "100.0",
                percent_succeeded: "100.0",
                :physical_description => "these are not the droids you are looking for",
                percent_failed: "0",
                status_code: "COMPLETED",
                structure: "<?xml version=\"1.0\" ?>\n<Item label=\"Betacam 1/1 Side 1 (40000000693483)\">\n  <Span label=\"Segment 1\" begin=\"00:00:00.000\" end=\"00:01:56.290\"/>\n  <Span label=\"Segment 2\" begin=\"00:01:58.457\" end=\"00:02:28.323\"/>\n</Item>",
                label: 'Betacam 1/1 Side 1 (40000000693483)',
                thumbnail_offset: 120457,
                poster_offset: 120457,
                comment: ["Upon inspection under the microscope, it appears that the groove may have been cut slightly off of vertical.",
                          "Ingest: Signal - Intermittent audio on linear and/or hifi tracks;"],
                files: [{:label=>"quality-low",
                          :id=>"MDPI_40000000693483_01_low.mp4",
                          :url=>"rtmp://bl-uits-ct-mdpi.uits.indiana.edu:1935/avalon_dark/_definst_/mp4:B-RTVS/GR00104460_MDPI_40000000693483_01_low_20160108_093019.mp4",
                          :hls_url=>"http://bl-uits-ct-mdpi.uits.indiana.edu/avalon_dark/media/B-RTVS/GR00104460_MDPI_40000000693483_01_low_20160108_093019.mp4",
                          :duration=>"354788",
                          :mime_type=>"application/mp4",
                          :audio_bitrate=>"1152000",
                          :audio_codec=>"pcm_s24le",
                          :video_bitrate=>"50004785",
                          :video_codec=>"mpeg2video",
                          :width=>"720",
                          :height=>"512"},
                        {:label=>"quality-medium",
                          :id=>"MDPI_40000000693483_01_med.mp4",
                          :url=>"rtmp://bl-uits-ct-mdpi.uits.indiana.edu:1935/avalon_dark/_definst_/mp4:B-RTVS/GR00104460_MDPI_40000000693483_01_med_20160108_093019.mp4",
                          :hls_url=>"http://bl-uits-ct-mdpi.uits.indiana.edu/avalon_dark/media/B-RTVS/GR00104460_MDPI_40000000693483_01_med_20160108_093019.mp4",
                          :duration=>"354788",
                          :mime_type=>"application/mp4",
                          :audio_bitrate=>"1152000",
                          :audio_codec=>"pcm_s24le",
                          :video_bitrate=>"50004785",
                          :video_codec=>"mpeg2video",
                          :width=>"720",
                          :height=>"512"},
                        {:label=>"quality-high",
                          :id=>"MDPI_40000000693483_01_high.mp4",
                          :url=>"rtmp://bl-uits-ct-mdpi.uits.indiana.edu:1935/avalon_dark/_definst_/mp4:B-RTVS/GR00104460_MDPI_40000000693483_01_high_20160108_093019.mp4",
                          :hls_url=>"http://bl-uits-ct-mdpi.uits.indiana.edu/avalon_dark/media/B-RTVS/GR00104460_MDPI_40000000693483_01_high_20160108_093019.mp4",
                          :duration=>"354788",
                          :mime_type=>"application/mp4",
                          :audio_bitrate=>"1152000",
                          :audio_codec=>"pcm_s24le",
                          :video_bitrate=>"50004785",
                          :video_codec=>"mpeg2video",
                          :width=>"720",
                          :height=>"512"}],
                file_location: 'rtmp://bl-uits-ct-mdpi.uits.indiana.edu:1935/avalon_dark/_definst_/mp4:B-RTVS/GR00104460_MDPI_40000000693483_01_high_20160108_093019.mp4',
                file_size: '2422702631',
                duration: '354788',
                date_digitized: '2015-09-29',
                display_aspect_ratio: (4/3.0).round(10).to_s,
                file_checksum: 'bc5bd4f942e55affbe29b643c58fded0',
                original_frame_size: '720x512',
                file_format: 'Moving image'
              }
              expect(@parsed_info).to eq(@fixture_info)
            end
          end

        end
        it 'can parse info for one file in an object' do
          expect(@media_object.get_file_info(@object, @file_info,@object[:json][:parts][0]['mdpi_barcode'],{}).class).to eq(Hash)
        end

      	# Turn this back on once file parsing has been finalized
      	xit 'writes an error when the file cannot be parsed' do
      	  expect(@media_object).to receive(:object_error_and_exit).at_least(:once)
      	  @media_object.get_file_info(@object, @file_info, {})
      	end

      	describe do
          let(:parse) { @media_object.get_all_file_info(@object, {}) }
      	  it 'can parse all files in an object' do
      	    expect(parse.class).to eq(Array)
      	    expect(parse[0].class).to eq(Hash)
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
      describe 'determing oclc numbers' do
        it 'returns nil when passed a non string' do
          non_strings = [nil, 1, 1.2, ['foo']]
          non_strings.each do |item|
            expect(@media_object.parse_oclc_field(item)).to be_nil
          end
        end
        it 'returns nil when a string of numbers and non numbers is passed in' do
          mixed_strings = ['foo1', '1foo', 'fo10', '.foo1', 'foo1.']
          mixed_strings.each do |item|
            expect(@media_object.parse_oclc_field(item)).to be_nil
          end
        end
        it 'returns a string with an ocm prefix when eight digits are passed in' do
          passed_val = '12345678'
          result_expected = 'ocm12345678'
          expect(@media_object.parse_oclc_field(passed_val)).to match(result_expected)
        end
        it 'returns a string with an ocn prefix when nine digits are passed in' do
          passed_val = '123456789'
          result_expected = 'ocn123456789'
          expect(@media_object.parse_oclc_field(passed_val)).to match(result_expected)
        end
        it 'returns a string with an oc prefix when ten digits are passed in' do
          passed_val = '1234567890'
          result_expected = 'oc1234567890'
          expect(@media_object.parse_oclc_field(passed_val)).to match(result_expected)
        end
        it 'returns a string with an oc prefix when more than ten digits are passed in' do
          passed_val = '123456789012'
          result_expected = 'oc123456789012'
          expect(@media_object.parse_oclc_field(passed_val)).to match(result_expected)
        end
        it 'right pads the ocm number with zeros when less than eight digits are passed in' do
          passed_val = '45678'
          result_expected = 'ocm00045678'
          expect(@media_object.parse_oclc_field(passed_val)).to match(result_expected)
        end
      end

      describe 'parsing mods' do
        it 'can parse the mods' do
          expect(@media_object.parse_mods(@object).class).to eq(Nokogiri::XML::Document)
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
          [:title, :creator, :date_issued, :other_identifier, :other_identifier_type].each do |field|
            expect(fields.keys.include? field).to be_truthy
            expect(fields[field]).not_to be_nil
          end
        end
        it 'should have a bibliographic id if provided' do
          #Use a fixture that has a catalog key
          @object = Objects.new(posted_content: load_sample_obj(filename: 'GR00034889.txt')).parse_request_body
          fields = @media_object.get_fields_from_mods(@object)
          expect(fields.keys.include? :bibliographic_id).to be_truthy
          expect(fields[:bibliographic_id]).not_to be_nil
        end
        it 'should have mdpi_barcode(s) if provided' do
          #Use a fixture that has a barcode
          @object = Objects.new(posted_content: load_sample_obj(filename: 'GR00034889.txt')).parse_request_body
          fields = @media_object.get_fields_from_mods(@object)
          expect(fields.keys.include? :other_identifier).to be_truthy
          expect(fields[:other_identifier]).to include('40000000089906')
          expect(fields[:other_identifier_type]).to include('mdpi barcode')
        end
        it 'should have a call number if provided' do
          #Use a fixture that has a call number
          @object = Objects.new(posted_content: load_sample_obj(filename: 'GR00034889.txt')).parse_request_body
          fields = @media_object.get_fields_from_mods(@object)
          expect(fields[:other_identifier_type].include? 'other').to be_truthy
          expect(fields[:other_identifier].size).to eq fields[:other_identifier_type].size
        end
        it 'should parse to "See other contributors" if no creator but other contributors provided' do
          #Use a fixture that has a catalog key
          @object = Objects.new(posted_content: load_sample_obj(filename: 'GR00104460.txt')).parse_request_body
          fields = @media_object.get_fields_from_mods(@object)
          expect(fields.keys.include? :creator).to be_truthy
          expect(fields[:creator]).to eq 'See other contributors'
        end
        it 'should parse creator if provided' do
          #Use a fixture that has a catalog key
          @object = Objects.new(posted_content: load_sample_obj(filename: 'GR00034889.txt')).parse_request_body
          fields = @media_object.get_fields_from_mods(@object)
          expect(fields.keys.include? :creator).to be_truthy
          expect(fields[:creator]).to eq 'Indiana University Philharmonic Orchestra.'
        end
        it 'should parse to "Unknown" if no creator or other contributors provided' do
          #Use a fixture that has a catalog key
          @object = Objects.new(posted_content: load_sample_obj(filename: 'GR00063679.txt')).parse_request_body
          fields = @media_object.get_fields_from_mods(@object)
          expect(fields.keys.include? :creator).to be_truthy
          expect(fields[:creator]).to eq 'Unknown'
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
      content = Objects.new(posted_content: load_sample_obj).parse_request_body
      @media_object.destroy_object(content[:json][:group_name])
      @media_object.register_object(content)
      expect(@media_object.object_status_as_json(content[:json][:group_name])['error']).to be_falsey
      expect{@media_object.object_error_and_exit(content[:json], 'test error')}.to raise_error
    end
  end

  describe 'posting media objects' do
    before :all do
      @object = Objects.new(posted_content: load_sample_obj(filename: @fixture)).parse_request_body
      @media_object.register_object(@object)
    end

    it 'properly forms a post request for an object' do
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      stub_request(:post, "https://youravalon.edu/media_objects.json").to_return(body: {id: 'pid'}.to_json, status: 200)
      @media_object.post_new_media_object(@object)
      results = @media_object.object_status_as_json(@object[:json][:group_name])
      expect(results['status']).to eq('deposited')
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

  describe 'updating a media objects' do
    before :each do
      @object = Objects.new(posted_content: load_sample_obj(filename: @fixture)).parse_request_body
      @media_object.register_object(@object)
      @avalon_pid = 'avalon:foo'
    end

    it 'properly forms a put request for a previously inserted object' do
      allow(MediaObject).to receive(:find_by).and_return(MediaObject.new(avalon_pid: @avalon_pid))
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      stub_request(:put, "https://youravalon.edu/media_objects/#{@avalon_pid}.json").to_return(body: { id: @avalon_pid }.to_json, status: 200)
      stub_request(:get, "https://youravalon.edu/media_objects/#{@avalon_pid}.json").to_return(body: { id: @avalon_pid }.to_json, status: 200)

      @media_object.update_media_object(@object)
      results = @media_object.object_status_as_json(@object[:json][:group_name])
      expect(results['status']).to eq('deposited')
      expect(results['error']).to be_falsey
      expect(results['avalon_pid']).to eq(@avalon_pid)
      expect(results['avalon_chosen']).to eq(Router.new.select_avalon(@object)[:url])
    end

    it 'properly forms a post request for a previously inserted but missing 6.x object' do
      allow(MediaObject).to receive(:find_by).and_return(MediaObject.new(avalon_pid: @avalon_pid))
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      stub_request(:post, "https://youravalon.edu/media_objects.json").to_return(body: {id: @avalon_pid}.to_json, status: 200)
      stub_request(:get, "https://youravalon.edu/media_objects/#{@avalon_pid}.json").to_return(body: { errors: ["#{@avalon_pid} not found"] }.to_json, status: 200)
      @media_object.update_media_object(@object)
      results = @media_object.object_status_as_json(@object[:json][:group_name])
      expect(results['status']).to eq('deposited')
      expect(results['error']).to be_falsey
      expect(results['avalon_pid']).to eq(@avalon_pid)
      expect(results['avalon_chosen']).to eq(Router.new.select_avalon(@object)[:url])
    end

    it 'properly forms a post request for a 5.x object that failed to migrate and saves 5.x identifier' do
      allow(MediaObject).to receive(:find_by).and_return(MediaObject.new(avalon_pid: @avalon_pid))
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      migrated_pid = 'migrated_pid'
      stub_request(:get, "https://youravalon.edu/media_objects/#{@avalon_pid}.json").to_return(status: 500)
      stub_request(:post, "https://youravalon.edu/media_objects.json").to_return(body: {id: migrated_pid}.to_json, status: 200)
      @media_object.update_media_object(@object)
      results = @media_object.object_status_as_json(@object[:json][:group_name])
      expect(results['status']).to eq('deposited')
      expect(results['error']).to be_falsey
      expect(results['avalon_pid']).to eq(migrated_pid)
      expect(results['avalon_chosen']).to eq(Router.new.select_avalon(@object)[:url])
      # 5.x identifier is saved
      expect(JSON.parse(MediaObject.where(group_name: @object[:json][:group_name]).first[:api_hash])['metadata']['identifier']).to eq([@avalon_pid])
    end

    it 'properly forms a put request for a previously inserted but now migrated object' do
      allow(MediaObject).to receive(:find_by).and_return(MediaObject.new(avalon_pid: @avalon_pid))
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      migrated_pid = 'migrated_pid'
      stub_request(:put, "https://youravalon.edu/media_objects/#{migrated_pid}.json").to_return(body: { id: migrated_pid }.to_json, status: 200)
      stub_request(:get, "https://youravalon.edu/media_objects/#{@avalon_pid}.json").to_return(body: { id: migrated_pid }.to_json, status: 200)

      @media_object.update_media_object(@object)
      results = @media_object.object_status_as_json(@object[:json][:group_name])
      expect(results['status']).to eq('deposited')
      expect(results['error']).to be_falsey
      expect(results['avalon_pid']).to eq(migrated_pid)
      expect(results['avalon_chosen']).to eq(Router.new.select_avalon(@object)[:url])
      # 5.x identifier is not overwritten
      expect(JSON.parse(MediaObject.where(group_name: @object[:json][:group_name]).first[:api_hash])['metadata']['identifier']).to eq([@avalon_pid])
    end

    it 'writes an error when the post request fails' do
      allow(@media_object).to receive(:get_object_collection_id).and_return('foo')
      stub_request(:put, "https://youravalon.edu/media_objects.json").to_return(body: {error: 'unh-oh'}.to_json, status: 500)
      expect{@media_object.update_media_object(@object)}.to raise_error
    end
  end

  describe 'determining existance of a media object' do
    before :all do
      MediaObject.create(group_name: 'TestingExistance', status: 'received', error: false, message: 'object received', created: '', last_modified: '', avalon_chosen: 'avalonfoobar', avalon_pid: '42', avalon_url: '', locked: false)
    end

    after :all do
      MediaObject.destroy_by(group_name: 'TestingExistance')
    end

    it 'returns false if the object has not been processed' do
      expect(@media_object.already_exists_in_avalon?({json:{group_name: 'no_entry'}})).to be_falsey
    end

    it 'returns false if the object has not been submitted to this avalon' do
      allow(@media_object).to receive(:attempt_to_route).and_return(url: 'something')
      expect(@media_object.already_exists_in_avalon?({json:{group_name: 'TestingExistance'}})).to be_falsey
    end

    it 'returns true if the object has been submitted to this avalon' do
      allow(@media_object).to receive(:attempt_to_route).and_return(url: 'avalonfoobar')
      allow(@media_object).to receive(:object_status_as_json).and_return('avalon_pid' => 42, 'avalon_chosen' => 'avalonfoobar')
      expect(@media_object.already_exists_in_avalon?({json:{group_name: 'TestingExistance'}})).to be_truthy
    end
  end
  describe 'working on objects in the queue' do
    it 'returns the oldest object in the queue that has status received' do
      created = DateTime.new(2001, 1, 1).iso8601
      MediaObject.destroy_by(created: created)
      m = MediaObject.new
      m.created = created
      m.status = 'received'
      m.save!
      expect(Objects.new.oldest_ready_object['id']).to eq(m.id)
    end

    it 'does not return the oldest object when the status is not received' do
      created = DateTime.new(1987, 1, 1).iso8601
      MediaObject.destroy_by(created: created)
      m = MediaObject.new
      m.created = created
      m.status = 'error'
      m.save!
      expect(Objects.new.oldest_ready_object['id']).not_to eq(m.id)
    end
  end
end
