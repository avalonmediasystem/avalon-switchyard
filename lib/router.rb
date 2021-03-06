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

require 'switchyard_configuration'
require 'retries'
require 'restclient'

# Stub class for routing content to Avalon, always picks the default currently
class Router
  # Selects the avalon to route the posted content to
  #
  # @param [Hash] the object posted to router as JSON with keys symbolized
  # @return [Hash] the Avalon selected with the keys :url and :api_token
  def select_avalon(object)
    # When it comes time to actually implement this, the Media Object function get_collection_name(object) will return the collection of an object
    # For now thought, default it is:
    avalons = SwitchyardConfiguration.new.load_yaml('avalons.yml')
    target_avalon = object['target_avalon']
    if target_avalon
      fail ArgumentError, "Target avalon #{target_avalon} not configured" unless avalons[target_avalon].present?
      target = avalons[target_avalon]
    else
      target = avalons['default']
    end
    target.symbolize_keys
  end


  # This function determines if an item is currently locked for transmission to Avalon or not
  #
  # @return [Boolean] true if an item is locked (in transmission), false if it is not
  def send_in_progress?
    !MediaObject.where(locked: true).empty?
  end
end
