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

# Class for creating and working with media objects
class MediaObject #< ActiveRecord::Base
  # Takes the information posts to the API in the request body and parses it
  #
  # @param [String] body The body of the post request
  # @return [Hash] return A parsed Hash of the request
  # @return return [Array <String>] :barcodes an array listing all MDPI barcodes sent in the reuqest
  # @return return [Hash] :json The JSON repsentation of the object
  def parse_request_body(body)
    return_hash = {}
    splitter = '----------'
    return_hash[:barcodes] = parse_barcodes(body.split(splitter)[0])
    #return_hash{:json}

    return_hash
  end

  # Takes the portion of the request body made up of barcodes and parses them
  # @param [String] codes A list of the codes seperated by endlines ("\n")
  # @return [Array <String>] An array of all barcodes, kept as strings due to potential leading zeros
  def parse_barcodes(codes)
    return codes.split("\n")
    rescue
      return [] #just return no codes if we can't extract any
  end
end
