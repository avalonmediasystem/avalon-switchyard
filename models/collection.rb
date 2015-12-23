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

require 'sinatra/activerecord'
require 'restclient'

# A fairly basic class for generating and decomissioning API tokens that grant access to Avalon Switchyard
class Collection < ActiveRecord::Base
  #TODO: Refactor this class to have class variables and stop passing stuff around between member functions via params

  # Determines if Switchyard has previously created a collection of this name for the selected avalon
  #
  # @param [String] name the name of the collection
  # @param [String] url the url of the avalon selected for this object
  #
  # @return [Hash] result a hash continuing inforation on the collection, exists: (boolean) and pid: (string)
  def collection_information(name, url)
    query_result = nil
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      query_result = Collection.find_by(name: name, avalon_url: url)
    end
    result = { exists: !query_result.nil? }
    result[:pid] = query_result[:pid] if result[:exists]
    result
  end

  # Saves a Switchyard created collection in the database so Switchyard can find it in the future
  #
  # @param [String] name the name of the collection
  # @param [String] pid the Avalon pid of the collection
  # @param [String] url the url of the Avalon the collection was created in
  def save_collection_in_database(name, pid, url)
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      Collection.create(name: name, pid: pid, avalon_url: url)
    end
  end

  # Returns the pid of a collection, creates a collection if one is not present
  #
  # @param [Hash] object the json hash of the posted object
  # @param [Hash] routing_target the Avalon information loaded by Router
  # @return [String] the pid of the collection
  def get_or_create_collection_pid(object, routing_target)
    info = collection_information(object[:metadata]['unit'], routing_target[:url])
    unless info[:exists]
      # TODO: Make this smarter for how it selects managers and names the collection_object
      # Currently name is used for both unit and collection name and default managers are always loaded (via passing nil)
      post_new_collection(name, name, managers_for_object(object), routing_target)
      info = collection_information(name, routing_target[:url])
    end
    info[:pid]
  end

  # Determines the proper managers for a collection
  # TODO: Implement, always returns nil
  # @param [Hash] the json hash of the posted object
  def managers_for_object(object)
    return nil
  end

  # Posts a new collection the Avalon
  #
  # @param [String] name The name of the new collection
  # @param [String] unit The unit of the new collection
  # @param [Array] managers An array of emails or avalon usernames who can manage the collection, loads default managers for the avalon if this is nil
  # @param [Hash] routing_target A hash of the Avalon information as loaded by managers
  # @return [String] the pid of the collection created
  def post_new_collection(name, unit, managers, routing_target)
    managers = routing_target[default_managers] if managers.nil?
    payload = {name: name,
               description: "Avalon Switchyard Created Collection for #{unit}",
               unit: unit,
               managers: managers
             }
    post_path = routing_target[:url] + '/admin/collections'
    resp = ''
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      resp = RestClient.post post_path, {:admin_collection => payload}, {:content_type => :json, :accept => :json, :'Avalon-Api-Key' => routing_target[:token]}
    end
    result = JSON.parse(resp.body).symbolize_keys
    fail "recieved an error #{result[:error]} when attempting to create collection #{payload} in Avalon #{@post_path}" unless result[:error].nil?
    save_collection_in_database(payload[:name], result[:id], routing_target[:url])
    result[:id]
  end
end