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

require 'yaml'
require 'pathname'
require 'byebug'

# Class that manages all the configurations needed for Switchyard
class SwitchyardConfiguration
  attr_accessor :path_to_configs

  # Sets the config pathname to the config directory
  #
  # @return [Pathname] the relative path to the config directory
  def path_to_configs
    @path_to_configs = Pathname(File.expand_path('../../config/', __FILE__))
  end

  # Loads a YAML File
  #
  # @param [String] filename the name of the config file to load
  # @raise [ArgumentError] the filename is not vaild (too short or not a .yml)
  # @raise [Errno::ENOENT] raised when the file is not found
  # @raise [Psych::SyntaxError] raised when the yml file syntax is incorrect
  # @return [Hash] hash of whatever was in the config file
  def load_yaml(filename)
    # Basic check for filename length, it needs to be at least a.yml
    fail ArgumentError, 'Filename is too short' if filename.size < 5
    fail ArgumentError, 'Filename does not indicate a yml file' if filename[filename.size - 4..filename.size - 1].downcase != '.yml'
    file = File.open(Pathname(path_to_configs.to_s + "/#{filename}")) # will raise Errno::ENOENT if not found
    yaml = YAML.load(file) # will raise Psych::SyntaxError if not a valid yaml file
    yaml[:source_file] = filename
    return yaml
  end
end
