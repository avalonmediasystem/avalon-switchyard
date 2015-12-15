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

describe 'configuring switchyard' do
  before :all do
    @configuration = SwitchyardConfiguration.new
  end

  describe 'config directory' do
    it 'returns a Pathname for the config directory' do
      expect(@configuration.path_to_configs.class).to eq(Pathname)
    end
  end

  describe 'loading yaml files' do
    it 'loads a yaml file' do
      expect(@configuration.load_yaml('switchyard.yml').class).to eq(Hash)
    end

    it 'raises an ENOENT error when the file is not present' do
      expect { @configuration.load_yaml('nofile.yml') }.to raise_error(Errno::ENOENT)
    end

    it 'raises an ArgumentError when the filename does not end in .yml' do
      expect { @configuration.load_yaml('a') }.to raise_error(ArgumentError)
    end

    it 'raises an ArgumentError when the filename is too short' do
      expect { @configuration.load_yaml('.yml') }.to raise_error(ArgumentError)
    end

    it 'raises a Psych error when the yaml is not valid' do
      # temp_path = Pathname(__FILE__) + '../../../'
      # Dir.chdir(temp_path) do
      #   `cp switchyard.rb config/README.yml`
      # end
      # Write a Bad File
      fp = Pathname(@configuration.path_to_configs + 'bad_file.yml')
      File.open(fp, 'w') { |file| file.write("foo: bar\nfoo2") }

      # Test to make sure it fails
      expect { @configuration.load_yaml('bad_file.yml') }.to raise_error(Psych::SyntaxError)

      # Cleanup the Bad File
      File.delete(fp)
    end
  end
end
