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

    it 'returns an empty list whenno mdpi barcodes are found' do
      expect(@media_object.parse_barcodes(nil)).to match([])
    end

    it 'returns a hash of the request json' do
      str = '{"part_total":3,"group_name":"GR00034889","parts":[]}'
      expect(@media_object.parse_json(str).class).to eq(Hash)
    end

    it 'returns an empty hash when the json cannot be parsed' do
      expect(@media_object.parse_json(nil)).to eq({})
    end
  end
end
