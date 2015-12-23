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
    test_collection = { name: Time.now.utc.iso8601.to_s, url: "https://bar#{@url}.edu", pid: 'foo' }
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_falsey
    sleep(1)
  end

  it 'creates a collection and determines it exists' do
    test_collection = { name: Time.now.utc.iso8601.to_s, url: "https://bar#{@url}.edu", pid: 'foo' }
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_falsey
    @collection.save_collection_in_database(test_collection[:name], test_collection[:pid], test_collection[:url])
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_truthy
    sleep(1)
  end

  it 'can retrieve the pid of a created collection' do
    test_collection = { name: Time.now.utc.iso8601.to_s, url: "https://bar#{@url}.edu", pid: Time.now.utc.to_s }
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:exists]).to be_falsey
    @collection.save_collection_in_database(test_collection[:name], test_collection[:pid], test_collection[:url])
    expect(@collection.collection_information(test_collection[:name], test_collection[:url])[:pid]).to eq(test_collection[:pid])
    sleep(1)
  end

  it 'requires both name and url to match' do
    expect(@collection.collection_information('darth', 'vader')[:exists]).to be_falsey
    @collection.save_collection_in_database('darth', 'sith', 'vader')
    expect(@collection.collection_information('darth', 'maul')[:exists]).to be_falsey
    expect(@collection.collection_information('Noooooo', 'vader')[:exists]).to be_falsey
    expect(@collection.collection_information('darth', 'vader')[:exists]).to be_truthy
  end

  describe 'creating a collection via POST to Avalon' do
    before :all do
      @data= {name: 'test', unit: 'test', managers: ['test1@example.edu', 'test2@example.edu']}
    end

    it 'attempts to create the collection via post' do
      expect(RestClient).to receive(:post).at_least(:once)
      @collection.post_new_collection(@data[:name], @data[:unit], @data[:managers], {url: 'https://test.edu', token: 'foo'})
    end

    it 'attempts to create the collection via RestClient post' do
      expect(RestClient).to receive(:post).at_least(:once)
      @collection.post_new_collection(@data[:name], @data[:unit], @data[:managers], {url: 'https://test.edu', token: 'foo'})
    end

    it 'forms a post request properly' do
      stub_request(:post, "https://test.edu/admin/collections").
        with(:body => {"admin_collection"=>{"name"=>"test", "description"=>"Avalon Switchyard Created Collection for test", "unit"=>"test", "managers"=>["test1@example.edu", "test2@example.edu"]}},
             :headers => {'Accept'=>'application/json', 'Accept-Encoding'=>'gzip, deflate', 'Avalon-Api-Key'=>'foo', 'Content-Length'=>'239', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "#{{id: 'pid'}.to_json}", :headers => {})

      res = @collection.post_new_collection(@data[:name], @data[:unit], @data[:managers], {url: 'https://test.edu', token: 'foo'})
      expect(res.code).to eq(200)
      expect(JSON.parse(res.body).symbolize_keys[:id]).to eq('pid')
    end
  end
end
