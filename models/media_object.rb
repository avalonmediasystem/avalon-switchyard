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
require 'nokogiri'

# Class for creating and working with media objects
class MediaObject < ActiveRecord::Base
  # Takes the information posts to the API in the request body and parses it
  #
  # @param [String] body The body of the post request
  # @return [Hash] return A parsed Hash of the request
  # @return return [Hash] :json The JSON repsentation of the object
  # @return return [Hash] :status A hash containing information on if the hash parsed successfully or not
  # @return :status [Boolean] :valid true if the posted request looks valid (may not be valid, but it has the keys we want)
  # @return :status [String] :errors Any errors encountered, nil if valid is true
  def parse_request_body(body)
    return_hash = {}
    return_hash[:json] = parse_json(body)
    check_request(return_hash)
  end

  # Checks the submitted request for valid json, and a group name
  #
  # @param [Hash] hashed_request The request broken up by parse_request_body
  # @return [Hash] hashed_request The submitted request with additional error information
  # @return return [Hash] :status A hash containing information on if the hash parsed successfully or not
  # @return :status [Boolean] :valid true if the posted request looks valid (may not be valid, but it has the keys we want)
  # @return :status [String] :errors Any errors encountered, nil if valid is true
  def check_request(hashed_request)
    failure_reasons = ''

    # Make sure we have JSON
    if hashed_request[:json].keys.size == 0
      failure_reasons << 'JSON could not be parsed.  '
    end

    # Make sure we have a group_name to register, skip this if we've already found errors
    if failure_reasons.size == 0 && (hashed_request[:json][:group_name].nil? || hashed_request[:json][:group_name].size == 0)
      failure_reasons << 'No group_name attribute could be found in the JSON'
    end

    result = { valid: failure_reasons.size == 0 }
    result[:error] = failure_reasons.strip unless result[:valid]
    hashed_request[:status] = result
    hashed_request
  end

  # Takes the portion of the request body and parses the JSON
  #
  # @param [String] request_json A string that can be parsed in to json
  # @return [Hash] A json hash of the param string, if the string cannot be parsed an empty hash is returned
  def parse_json(request_json)
    return JSON.parse(request_json).symbolize_keys
  rescue
    return {} # just return empty hash if we can't parse the json
  end

  # Registers the object in my sql
  #
  # @param [Hash] object The object as parsed by parse_request_body
  # @return [Hash] results a hash containing the results of the reigstration
  # @return results [Boolean] :success true if successfull, false if not
  # @return results [String] :group_name the group_name of the object created, only return if registration was succcessful
  def register_object(obj)
    destroy_object(obj[:json][:group_name])
    t = Time.now.utc.iso8601.to_s
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      MediaObject.create(group_name: obj[:json][:group_name], status: 'received', error: false, message: 'object rceived, awaiting routing', last_modified: t, created: t, locked: false)
      return { success: true, group_name: obj[:json][:group_name] }
    end
  rescue
    return { success: false }
  end

  # Deletes a media object from sql using the group name
  #
  # @param [String] group_name The group_name attribute of the object
  # @return [Hash] results a hash containing the results of the destruction
  # @return results [Boolean] :success true if successfull, false if not
  # @return results [String] :group_name the group_name of the object created, only return if deletion was successfull
  def destroy_object(group_name)
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      MediaObject.destroy_all(group_name: group_name)
      return { success: true, group_name: group_name }
    end
  rescue
    return { success: false }
  end

  # Look up the current status of an object and return it
  #
  # @param [String] group_name The group_name of the object
  # @return [Hash] A hash of the obj's SQL row formatted for json or the error
  def object_status_as_json(group_name)
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      obj = MediaObject.find_by(group_name: group_name)
      rv = { success: false, error: 404, message: 'object not found in database' }
      rv = JSON.parse(obj.to_json) unless obj.nil?
      return rv
    end
  rescue
    return { success: false, error: 500 }
  end

  # Transforms the posted object into the json form needed to submit it to an Avalon instance
  #
  # @param [Hash] object The JSON submitted to the router with its keys symbolized
  # @return [JSON] the object in the json form needed to submit it to Avalon
  def transform_object(object)
    byebug
    files = {}
    # TODO: Refactor this out into some sub functions and follow DRY regarding the object error call

    target = attempt_to_route(object)

    # Setup the fields needed for the ingestation
    fields = {}
    begin
      fields = get_fields_from_mods(object)
      fields[:collection_id] = get_object_collection_id(object, target)
    rescue
      object_error_and_exit(object, 'an unknown error occurred while attempt to set the mods')
    end

    files = get_all_file_info(object)
    {fields: fields, files: files}.to_json
  end

  # Gets the file info for an object in the form needed to submit to Avalon, writes an error and terminates the thread if it cannot
  #
  # @param [Hash] object the object as posted
  # @return [Array <Hash>] All the files hashed for Avalon
  def get_all_file_info(object)
    return_array = []
    # Loop over every part
    object[:parts].each do |part|
      # Loop over all the files in a part
      part['files'].keys.each do |file|
        return_array << get_file_info(object, file)
      end
    end
  end

  # Gets all needed information on a file from its posted string
  #
  # @param [Hash] object the object passed to switchyard
  # @param [String] file the representation of the file's information in a string that can be parsed as XML
  # @return [Hash] a hash of the file ready for addition to :files
  def get_file_info(object, file)
    file_hash = {}
    begin
      info = Hash.from_xml(file['structure'])['item']
    rescue
      object_error_and_exit(object, "failed to xml describing the object's files information as xml")
    end

    # Setup the defaults
    file_hash[:workflow_name] = 'avalon'
    file_hash[:percent_complete] = '100.0'
    file_hash[:percent_succeeded] = '100.0'
    file_hash[:percent_failed] = '0'
    file_hash[:status_code] = 'COMPLETED'
    file_hash[:label] = info['label']

    # Get the file structure as XML and delete the label part out of it
    # We don't need this, so we only error if it is there but badly formed
    begin
      file_hash[:structure] = info['Span'].to_xml.to_s unless info['Span'].nil?
    rescue
      object_error_and_exit(object, 'failed to parse the xml representing the file structure')
    end

    # Get the rest of the file info
    # TODO: For now we are only supporting the high derivative
    high_data = file['structure']['high']
    object_error_and_exit(object, 'failed to find high quality deriviative for object') if high_data.nil?
    ffprobe_data = Hash.from_xml(high_data['ffprobe'])['ffprobe']

    file_hash[:file_location] = high_data['url']
    begin
      file_hash[:file_size] = ffprobe_data['format']['size']
      file_hash[:duration] = ffprobe_data['format']['duration']
      file_hash[:poster_offset] = '0:01'
      file_hash[:thumbnail_offset] = '0:01'
      file_hash[:date_ingested] = DateTime.parse(file['ingest']).beginning_of_day.strftime("%Y-%m-%d")
      file_hash[:display_aspect_ratio] = 'placeholder' # TODO: some ffprobes seem to have this, some don't, it is not consistent
      file_hash[:checksum] = 'placeholder'
      file_hash[:original_frame_size] = 'placeholder'
    rescue
      object_error_and_exit(object, 'failed to parse ffprobe data for object') if high_data.nil?
    end
    file_hash
  end

  # Updates the status of an object in the SQL database for future queries
  #
  # @param [String] The group_name of the object
  # @param [Hash] changes, the changes to make in the form of {sql_column_name: value}
  def update_status(group_name, changes)
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      obj = MediaObject.find_by(group_name: group_name)
      obj.update(changes)
    end
  end

  # Writes out an alert that an object failed for some reason and exits the thread
  #
  # @param [Hash] object the posted object in json
  # @param [String] message the error message to write
  def object_error_and_exit(object, message)
    update_status(object[:group_name], error: true, message: message, last_modified: Time.now.utc.iso8601)
    exit
  end

  # Attempts to route the object to an avalon, logs an error in the db and triggers an exit of the thread if the object cannot be routed
  #
  # @param [Hash] object Hash of the object supplied
  # @return [String] the url of the target avalon
  def attempt_to_route(object)
    target = Router.new.select_avalon(object)
    object_error_and_exit(object, 'could not route to an avalon') if target.nil?
    target
  end

  # Determines the pid of a collection for an object, if the pid cannot be determined it logs an error in the db and halts
  #
  # @param [Hash] object a hash of the object
  # @return [String] target the url of the object
  def get_object_collection_id(object, target)
    # Find or create the collection
    collection_pid = Collection.new.get_or_create_collection_pid(object, target)
    object_error_and_exit(object, 'could not assign to a collection') if collection_pid.nil?
    collection_pid
  end

  # Extract the required fields from the mods for creating a collection, if the fields cannot be extracted it logs an error in the db and halts
  #
  # @param [Hash] object the object as a hash
  # @return [Hash] a hash of the fields
  def get_fields_from_mods(object)
    # Populate the rest if Fields
    # Make sure the XML can be parsed by having Nokogiri take a pass at it
    fields = {}
    hash_mods = parse_mods(object)

    # Check for the default fields we need, we may only have these if a machine generated mods
    fields[:title] = hash_mods['titleInfo']['title'] || 'Untitled'
    fields[:creator] = ['MDPI']
    fields[:date_issued] = hash_mods['originInfo'] || '19uu'

    # Check for a creation date
    unless hash_mods['recordInfo'].nil?
      fields[:date_created] = hash_mods['recordInfo']['recordCreationDate']
    end
    fields[:date_created] = Time.now.to_s.delete(' ') if fields[:date_created].nil?

    # Get the CatKey if we have one
    fields[:bibliographic_id] = object[:metadata]['iucat_barcode']

    fields
  end

  # Gets the collection name for an object,
  def get_collection_name(object)
    begin
      return parse_mods(object)['identifier'][0]
    rescue
      object_error_and_exit(object, 'failed to determine target collection for object')
    end
  end

  # Parse the mods in the object as a hash, if this fails it will write an error to the db and end the thread
  #
  # @param [Hash] object The media object in its posted json hash
  # @return [Hash] the mods as a hash with keys as strings
  def parse_mods(object)
    begin
      hash_mods = Hash.from_xml(object[:metadata]['mods'])['mods']
    rescue
      object_error_and_exit(object, 'failed to parse mods as XML')
    end
    hash_mods
  end

end
