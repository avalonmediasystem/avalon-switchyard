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
require 'restclient'
require 'date'

# Class for creating and working with media objects
class Objects
  # Posts a new media object to an Avalon, creates the collection first if needed
  # Writes the status of the submission to the database
  #
  # @param [Hash] object the object as deposited in Switchyard
  def post_new_media_object(object)
    routing_target = attempt_to_route(object)
    payload = transform_object(object)
    post_path = routing_target[:url] + '/media_objects.json'
    resp = ''
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      resp = RestClient.post post_path, payload, {:content_type => :json, :accept => :json, :'Avalon-Api-Key' => routing_target[:api_token]}
      Sinatra::Application.settings.switchyard_log.info resp
    end
    $log.debug "Posting MediaObject response: #{resp}"
    object_error_and_exit(object, "Failed to post to Avalon, returned result of #{resp.code} and #{resp.body}") unless resp.code == 200
    pid = JSON.parse(resp.body).symbolize_keys[:id]
    update_info = { status: 'deposited',
                    error: false,
                    last_modified: Time.now.utc.iso8601.to_s,
                    avalon_chosen: routing_target[:url],
                    avalon_pid: pid,
                    avalon_url: "#{routing_target[:url]}/media_objects/#{pid}",
                    message: 'successfully deposited in avalon' }
    update_status(object[:json][:group_name], update_info)
  end

  # Updates a media object currently in Avalon, creates the collection first if needed
  # Writes the status of the submission to the database
  #
  # @param [Hash] object the object as deposited in Switchyard
  # TODO: refactor this and post_new_media_object to follow DRY
  def update_media_object(object)
    routing_target = attempt_to_route(object)
    payload = transform_object(object)
    payload = JSON.parse(payload)
    payload[:replace_masterfiles] = true # overwrite the current structure
    payload = payload.to_json
    put_path = routing_target[:url] + "/media_objects/#{MediaObject.find_by(group_name: object[:json][:group_name])[:avalon_pid]}.json"
    resp = ''
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      resp = RestClient.put put_path, payload, {:content_type => :json, :accept => :json, :'Avalon-Api-Key' => routing_target[:api_token]}
    end
    $log.debug "Updating MediaObject response: #{resp}"
    object_error_and_exit(object, "Failed to update media object in Avalon, returned result of #{resp.code} and #{resp.body}") unless resp.code == 200
    pid = JSON.parse(resp.body).symbolize_keys[:id]
    update_info = { status: 'deposited',
                    error: false,
                    last_modified: Time.now.utc.iso8601.to_s,
                    avalon_chosen: routing_target[:url],
                    avalon_pid: pid,
                    avalon_url: "#{routing_target[:url]}/media_objects/#{pid}",
                    message: 'successfully deposited in avalon' }
    update_status(object[:json][:group_name], update_info)
  end

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

  # Determines if the item already exists in an instance of avalon
  # uses the current state of the object to determine a target avalon and checks the switchyard database to see if a previous version was sent to this avalon
  #
  # @param [Hash] object the object submitted to Switchyard
  # @return [Boolean] whether or not it exists
  def already_exists_in_avalon?(object)
    status = object_status_as_json(object[:json][:group_name])
    return false if status.nil? || status['avalon_pid'].nil? # This means we have never processed this object before

    # If the object is already on file we need to make sure it has an avalon pid in the avalon
    # we plan to send it to (since it might be on file in a different avalon)
    $log.debug "Attemping to check match with urls of #{attempt_to_route(object)[:url]} and #{status}, #{status[:avalon_chosen]}"
    attempt_to_route(object)[:url] == status['avalon_chosen']
  end

  # Checks the posted request for valid json, and a group name
  #
  # @param [Hash] hashed_request The request broken up by parse_request_body
  # @return [Hash] hashed_request The posted request with additional error information
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
  def register_object(object)
    #current_object = {}
    #current_object = object_status_as_json(object[:json][:group_name]) if already_exists_in_avalon?(object)

    #destroy_object(object[:json][:group_name])
    t = Time.now.utc.iso8601.to_s
    changes = {status: 'received', error: false, message: 'object received', last_modified: t}
    with_retries(max_tries: Sinatra::Application.settings.max_retries, base_sleep_seconds:  0.1, max_sleep_seconds: Sinatra::Application.settings.max_sleep_seconds) do
      #MediaObject.create(group_name: object[:json][:group_name], status: 'received', error: false, message: 'object received', created: current_object[:created] || t, last_modified: t, avalon_chosen: current_object[:avalon_chosen] || '', avalon_pid: current_object[:avalon_pid] || '', avalon_url: current_object[:avalon_url] || '', locked: false) if MediaObject.find_by(group_name: object[:json][:group_name]).nil?
      MediaObject.create(group_name: object[:json][:group_name], created: t) if MediaObject.find_by(group_name: object[:json][:group_name]).nil?
      update_status(object[:json][:group_name], changes)
      return { success: true, group_name: object[:json][:group_name] }
    end
  rescue Exception => e
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
  # @param [Hash] object The JSON posted to the router with its keys symbolized
  # @return [String] the object in the json format needed to submit it to Avalon
  def transform_object(object)
    fields = {}
    begin
      fields = get_fields_from_mods(object)
    rescue Exception => e
      object_error_and_exit(object, 'an unknown error occurred while attempt to set the mods')
    end

    files = get_all_file_info(object)
    collection_id = get_object_collection_id(object, attempt_to_route(object))
    final = { fields: fields, files: files, collection_id: collection_id }
#FIXME!!!!
    final[:import_bib_record] = true unless fields[:bibliographic_id].nil?
    return final.to_json
  end

  # Gets the file info for an object in the form needed to submit to Avalon, writes an error and terminates the thread if it cannot
  #
  # @param [Hash] object the object as posted
  # @return [Array <Hash>] All the files hashed for Avalon
  def get_all_file_info(object)
    return_array = []
    # Loop over every part
    object[:json][:parts].each do |part|
      # Loop over all the files in a part
      part['files'].keys.each do |key|
        return_array << get_file_info(object, part['files'][key]).merge({other_identifier: part['mdpi_barcode']})
      end
    end
    return_array
  end

  # Gets all needed information on a file from its posted string
  #
  # @param [Hash] object the object passed to switchyard
  # @param [String] file the representation of the file's information in a string that can be parsed as XML
  # @return [Hash] a hash of the file ready for addition to :files
  def get_file_info(object, file)
    # TODO: Split me up further once file parsing is finalized
    file_hash = {}

    # Setup the defaults
    file_hash[:workflow_name] = 'avalon'
    file_hash[:percent_complete] = '100.0'
    file_hash[:percent_succeeded] = '100.0'
    file_hash[:percent_failed] = '0'
    file_hash[:status_code] = 'COMPLETED'

    # Use provided xml as-is
    file_hash[:structure] = file['structure']

    # Get masterfile label from provided structure
    structure = Nokogiri::XML(file['structure'])
    file_hash[:label] = structure.xpath('//Item').first['label']

    # Get time offsets from structure. Use second segment if available, otherwise use first, then add 2 seconds.
    begintimes = structure.xpath('//Span').collect{|d|d['begin']}
    offset = structure_time_to_milliseconds(begintimes[[2,begintimes.count].min-1])
    file_hash[:poster_offset] = file_hash[:thumbnail_offset] = offset+2000

    # Get info for derivatives. Use highest quality derivative available for item-level values.
    file_hash[:files] = []
    quality_map = {'low'=>'quality-low','med'=>'quality-medium','high'=>'quality-high'}
    ['low','med','high'].each do |quality|
      # Set derivative-level info
      derivative = file['q'][quality] or next
      begin
        ffprobe_selected = derivative['ffprobe']
        ffprobe_selected ||= file['q']['prod']['ffprobe'] if file['q']['prod']
        ffprobe_selected ||= file['q']['mezz']['ffprobe'] if file['q']['mezz']

        ffprobe_xml = Nokogiri::XML(ffprobe_selected)
        audio_stream =   ffprobe_xml.xpath('//stream[@codec_type=\'audio\'][disposition/@default=\'1\']').first
        audio_stream ||= ffprobe_xml.xpath('//stream[@codec_type=\'audio\']').first || {}
        video_stream =   ffprobe_xml.xpath('//stream[@codec_type=\'video\'][disposition/@default=\'1\']').first
        video_stream ||= ffprobe_xml.xpath('//stream[@codec_type=\'video\']').first || {}
        format = ffprobe_xml.xpath('//format').first
        derivative_hash = {label: quality_map[quality]}
        derivative_hash[:id] = derivative['filename']
        derivative_hash[:url] = derivative['url_rtmp']
        derivative_hash[:hls_url] = derivative['url_http']
        derivative_hash[:duration] = (format['duration'].to_f * 1000).to_i.to_s
        derivative_hash[:mime_type] = MIME::Types.type_for(derivative['filename']).first.content_type
        derivative_hash[:audio_bitrate] = audio_stream['bit_rate']
        derivative_hash[:audio_codec] = audio_stream['codec_name']
        derivative_hash[:video_bitrate] = video_stream['bit_rate']
        derivative_hash[:video_codec] = video_stream['codec_name']
        derivative_hash[:width] = video_stream['width']
        derivative_hash[:height] = video_stream['height']
        file_hash[:files] << derivative_hash
      rescue
        object_error_and_exit(object, 'failed to parse ffprobe data for derivative(s)')
      end

      # Set masterfile-level info (highest level is set last)
      file_hash[:file_location] = derivative_hash[:url]
      begin
        file_hash[:file_size] = format['size']
        file_hash[:duration] = (format['duration'].to_f * 1000).to_i.to_s
        # FFProbe sends the ratio as 4:3 or similar, but Avalon needs this as a fraction
        # So we need to make a fraction for avalon

        begin
          ratio = video_stream['display_aspect_ratio'].split(':')
          file_hash[:display_aspect_ratio] = (ratio[0].to_i * 1.0 / ratio[1].to_i).round(10).to_s
        rescue
          # If we have a ratio but can't parse it, just default to 4:3 shown as 1.33
          file_hash[:display_aspect_ratio] = '1.33' unless video_stream['display_aspect_ratio'].nil?
        end
        file_hash[:original_frame_size] = "#{derivative_hash[:width]}x#{derivative_hash[:height]}" if derivative_hash[:width] and derivative_hash[:height]
      rescue
        object_error_and_exit(object, 'failed to parse ffprobe data for object')
      end
    end

    #Set masterfile-level info
    begin
      file_hash[:date_digitized] = Date.parse(file['ingest']).strftime('%Y-%m-%d')
    rescue
      # Still rescue if we can't parse it, but now don't supply a default just leave it blank
      #file_hash[:date_ingested] = Time.now.strftime('%Y-%m-%d')
    end
    file_hash[:file_checksum] = file["master_md5"]
    file_hash[:file_format] = get_file_format(object)
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
    update_status(object[:json][:group_name], status: 'failed', error: true, message: message, last_modified: Time.now.utc.iso8601)
    fail "error with #{object[:json][:group_name]}, see database record"
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
    mods = parse_mods(object)

    # Check for the default fields we need, we may only have these if a machine generated mods
    fields[:title] = mods.xpath('/mods/titleInfo/title').text
    fields[:title] = object[:json][:metadata]['call_number'] || 'Unknown' if fields[:title] == ''
    fields[:creator] = ['MDPI']
    fields[:date_issued] = mods.xpath('/mods/originInfo/dateIssued')[0].text
    fields[:date_issued] = '19uu' if fields[:date_issued] == ''

    # Check for a creation date
    # This is commented out because this is getting the wrong date
    # We are currently not passed the proper creation date (when the physical item was created)
    # So we cannot fill this field in, thus nixed
    # unless hash_mods['recordInfo'].nil?
    #   fields[:date_created] = hash_mods['recordInfo']['recordCreationDate']
    # end
    # fields[:date_created] = Time.now.to_s.delete(' ') if fields[:date_created].nil?

    # Get the CatKey if we have one
    fields[:bibliographic_id] = object[:json][:metadata]['catalog_key'] unless object[:json][:metadata]['catalog_key'].nil?
    fields[:other_identifier] = [object[:json][:group_name]]
    fields[:other_identifier_type] = ['mdpi group']

    fields
  end

  # Gets the collection name for an object,
  def get_collection_name(object)
    begin
      return parse_mods(object).xpath('/mods/identifier').text
    rescue
      object_error_and_exit(object, 'failed to determine target collection for object')
    end
  end

  # Parse the mods in the object as XML, if this fails it will write an error to the db and end the thread
  #
  # @param [Hash] object The media object in its posted json hash
  # @return [Nokogiri::XML::Document ] the mods as a Nokogiri XML Documents
  def parse_mods(object)
    begin
      parsed_mods = Nokogiri::XML(object[:json][:metadata]['mods'])
      return parsed_mods.remove_namespaces!
    rescue
      object_error_and_exit(object, 'failed to parse mods as XML')
    end
  end

  # Gets the file format from the mods, writes an error and terminates if the file format cannot be found
  #
  # @param [Hash] the object as passed to Switchyard
  # @return [String] the file format used for this file
  def get_file_format(object)
    format = parse_mods(object).xpath('/mods/typeOfResource').text
    # Currently the two values for format in the mods are 'moving image' and 'sound recording'
    # Avalon wants these to be 'Moving image' and 'Sound'
    #change Moving Image to Moving image
    format = 'Moving image'
    format = 'Sound' if object[:json][:metadata]['audio'].downcase == 'true' # knock off the recording part if this is sound
    return format
  rescue
    object_error_and_exit(object, 'failed to parse file_format from mods')
  end

  # Transforms to milliseconds time string with format 00:00:00.0000
  #
  # @param [String] the time to transform
  # @return [Int] the time in milliseconds
  def structure_time_to_milliseconds(value)
    milliseconds = if value.is_a?(Numeric)
      value.floor
    elsif value.is_a?(String)
      result = 0
      segments = value.split(/:/).reverse
      segments.each_with_index { |v,i| result += i > 0 ? v.to_f * (60**i) * 1000 : (v.to_f * 1000) }
      result.to_i
    else
      value.to_i
    end
    milliseconds
  end

end
