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
require 'json'
require 'retries'

# Class for creating and working with media objects
class MediaObject < ActiveRecord::Base
  # Takes the information posts to the API in the request body and parses it
  #
  # @param [String] body The body of the post request
  # @return [Hash] return A parsed Hash of the request
  # @return return [Array <String>] :barcodes an array listing all MDPI barcodes sent in the reuqest
  # @return return [Hash] :json The JSON repsentation of the object
  # @return return [Hash] :status A hash containing information on if the hash parsed successfully or not
  # @return :status [Boolean] :valid true if the posted request looks valid (may not be valid, but it has the keys we want)
  # @return :status [String] :errors Any errors encountered, nil if valid is true
  def parse_request_body(body)
    return_hash = {}
    splitter = '----------'
    return_hash[:barcodes] = parse_barcodes(body.split(splitter)[0])
    return_hash[:json] = parse_json(body.split(splitter)[1])
    check_request(return_hash)
  end

  # Checks the submitted request for at least one barcode, valid json, and a group name
  #
  # @param [Hash] hashed_request The request broken up by parse_request_body
  # @return [Hash] hashed_request The submitted request with additional error information
  # @return return [Hash] :status A hash containing information on if the hash parsed successfully or not
  # @return :status [Boolean] :valid true if the posted request looks valid (may not be valid, but it has the keys we want)
  # @return :status [String] :errors Any errors encountered, nil if valid is true
  def check_request(hashed_request)
    failure_reasons = ''

    # Make sure we have barcodes
    if hashed_request[:barcodes].size == 0
      failure_reasons << 'No barcodes found on parse.  '
    end

    # Make sure we have JSON
    if hashed_request[:json].keys.size == 0
      failure_reasons << 'JSON could not be parsed.  '
    end

    # Make sure we have a group_name to register, skip this if we've already found errors
    if failure_reasons.size == 0 && (hashed_request[:json][:group_name].nil? || hashed_request[:json][:group_name].size == 0)
      failure_reasons << 'No group_name attribute could be found in the JSON'
    end

    result = { valid: failure_reasons.size == 0 }
    result[:errors] = failure_reasons.strip unless result[:valid]
    hashed_request[:status] = result
    hashed_request
  end

  # Takes the portion of the request body made up of barcodes and parses the JSON
  #
  # @param [String] request_json A string that can be parsed in to json
  # @return [Hash] A json hash of the param string, if the string cannot be parsed an empty hash is returned
  def parse_json(request_json)
    return JSON.parse(request_json).symbolize_keys
  rescue
    return {} # just return empty hash if we can't parse the json
  end

  # Takes the portion of the request body made up of barcodes and parses them
  # @param [String] codes A list of the codes seperated by endlines ("\n")
  # @return [Array <String>] An array of all barcodes, kept as strings due to potential leading zeros, if this cannot be parsed an empty array is returned
  def parse_barcodes(codes)
    return codes.split("\n")
  rescue
    return [] # just return no codes if we can't extract any
  end

  # Registers the object in my sql
  #
  # @param [Hash] object The object as parsed by parse_request_body
  # @return [Boolean] true if the operation has succeed, false if it has not
  def register_object(obj)
    destroy_object(obj[:json][:group_name])
    t = Time.now.utc.iso8601.to_s
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      MediaObject.create(group_name: obj[:json][:group_name], status: 'recieved', error: false, last_modified: t, created: t, locked: false)
      return true
    end
  rescue
    return false
  end

  # Deletes a media object from sql using the group name
  #
  # @param [String] group_name The group_name attribute of the object
  # @return [Boolean] true if the object was deleted (or not was present to be deleted), false if there was an error deleting it
  def destroy_object(group_name)
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      MediaObject.destroy_all(group_name: group_name)
      return true
    end
  rescue
    return false
  end
end
