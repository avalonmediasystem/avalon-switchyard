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

describe 'collection management' do
  before :all do
    @collection = Collection.new
    Collection.destroy_all
  end

  it 'determines of Switchyard previously created the collection' do
    test_collection = { name: Time.now.utc.iso8601.to_s, url: "https://bar#{@url}.edu", pid: 'foo', fullname: 'A human readable unit name'}
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_falsey
    sleep(1)
  end

  it 'creates a collection and determines it exists' do
    test_collection = { name: Time.now.utc.iso8601.to_s, url: "https://bar#{@url}.edu", pid: 'foo', fullname: 'A human readable unit name'}
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_falsey
    @collection.save_collection_in_database(test_collection[:name], test_collection[:pid], test_collection[:url], test_collection[:fullname])
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_truthy
    sleep(1)
  end

  it 'can retrieve the pid of a created collection' do
    test_collection = { name: Time.now.utc.iso8601.to_s, url: "https://bar#{@url}.edu", pid: Time.now.utc.to_s, fullname: 'A human readable unit name'}
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_falsey
    @collection.save_collection_in_database(test_collection[:name], test_collection[:pid], test_collection[:url], test_collection[:fullname])
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:pid]).to eq(test_collection[:pid])
    sleep(1)
  end

  it 'requires both name and url to match' do
    expect(@collection.collection_information('darth', 'vader')[:exists]).to be_falsey
    @collection.save_collection_in_database('darth', 'sith', 'vader', 'Anakin Skywalker')
    expect(@collection.collection_information('darth', 'maul')[:exists]).to be_falsey
    expect(@collection.collection_information('Noooooo', 'vader')[:exists]).to be_falsey
    expect(@collection.collection_information('darth', 'vader')[:exists]).to be_truthy
  end

  describe 'creating a collection via POST to Avalon' do
    before :all do
      @data= {name: 'test', unit: 'test', managers: ['test1@example.edu', 'test2@example.edu'], fullname: 'A human readable unit name'}
    end

    it 'attempts to create the collection via post' do
      stub_request(:post, "https://test.edu/admin/collections").
        with(:body => {"admin_collection"=>{"name"=>"A human readable unit name", "description"=>"Avalon Switchyard Created Collection for test", "unit"=>"A human readable unit name", "managers"=>["test1@example.edu", "test2@example.edu"] , "default_read_groups"=>["BL-LDLP-MDPI-MANAGERS-test"]}},
             :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Avalon-Api-Key'=>'foo', 'Content-Length'=>'366', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "#{{id: 'pid'}.to_json}", :headers => {})
      @collection.post_new_collection(@data[:name], @data[:unit], @data[:managers], {url: 'https://test.edu', api_token: 'foo'})
    end

    it 'forms a post request properly' do
      stub_request(:post, "https://test.edu/admin/collections").
        with(:body => {"admin_collection"=>{"name"=>"A human readable unit name", "description"=>"Avalon Switchyard Created Collection for test", "unit"=>"A human readable unit name", "managers"=>["test1@example.edu", "test2@example.edu"], "default_read_groups"=>["BL-LDLP-MDPI-MANAGERS-test"]}},
             :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Avalon-Api-Key'=>'foo', 'Content-Length'=>'366', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "#{{id: 'pid'}.to_json}", :headers => {})

      expect(@collection.post_new_collection(@data[:name], @data[:unit], @data[:managers], {url: 'https://test.edu', api_token: 'foo'})).to eq('pid')
    end

    it 'calls post collection if a collection does not exist' do
      allow(@collection).to receive(:collection_information).and_return({exists: false}, {exists: true, pid: 'foo'})
      expect(@collection).to receive(:post_new_collection).at_least(:once).and_return('foo')
      expect(@collection.get_or_create_collection_pid({stub: 'object', json: { metadata: {'unit'=>'foo'}}}, url: 'http://somewhere.edu')).to eq('foo')
    end
  end

  describe '#lookup_fullname' do
    it 'should lookup a full name' do
      expect(Collection.lookup_fullname('test')).to eq 'A human readable unit name'
    end
    it 'should default to the passed name if no long form is found' do
      expect(Collection.lookup_fullname('none')).to eq 'none'
    end
  end

  describe 'collection creation errors' do
    before :all do
      @data= {name: 'test', unit: 'test', managers: ['test1@example.edu', 'test2@example.edu'], fullname: 'A human readable unit name'}
    end

    it 'captures a 422 error and logs it' do
      stub_request(:post, "https://test.edu/admin/collections").to_return(:status => 422)
      expect(Sinatra::Application.settings.switchyard_log).to receive(:error).at_least(:once)
      expect{ @collection.post_new_collection(@data[:name], @data[:unit], @data[:managers], url: 'https://test.edu') }.to raise_error(RuntimeError)
    end

    it 'sets the object to an error state when it cannot create the collection' do
      allow(@collection).to receive(:post_new_collection).and_raise(RuntimeError)
      allow(@collection).to receive(:collection_information).and_return({})
      obj = Objects.new
      allow(Objects).to receive(:new).and_return(obj)
      expect(obj).to receive(:object_error_and_exit).at_least(:once).and_raise(RuntimeError)
      expect{@collection.get_or_create_collection_pid({json: {metadata: {'unit'=>'test'}}}, {})}.to raise_error(RuntimeError)
    end
  end
  describe 'default read groups' do
    it 'adds the prefix to the group name' do
      name = 'B-FOO'
      expected_result = ['BL-LDLP-MDPI-MANAGERS-B-FOO']
      expect(@collection.populate_read_group(name)).to eq(expected_result)
    end
  end
end

describe 'Kinsey Tests' do
  it 'places an error state on all kinsey objects when attempting to create the collection' do
    @collection = Collection.new
    allow(Collection).to receive(:new).and_return(@collection)
    @object = Objects.new
    allow(Objects).to receive(:new).and_return(@object)
    object = @object.parse_request_body(load_fail_object('GRKinseyFail.txt'))
    expect(@object).to receive(:object_error_and_exit).with(object, 'Kinsey Item').at_least(:once).and_raise(RuntimeError)
    expect{@collection.get_or_create_collection_pid(object, {})}.to raise_error(RuntimeError)
  end

end
