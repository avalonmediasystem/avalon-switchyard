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

describe 'api token generation and management' do
  before :all do
    @api_token = ApiToken.new
  end

  describe 'generating token' do
    it 'generates the token as a string' do
      expect(@api_token.generate_token.class).to eq(String)
    end

    it 'has a default n of 36 characters' do
      expect(@api_token.generate_token.size).to eq(SecureRandom.urlsafe_base64(36).size)
    end

    it 'has allows the user to set n' do
      expect(@api_token.generate_token(n: 22).size).to eq(SecureRandom.urlsafe_base64(22).size)
    end
  end

  describe 'creating tokens and checking uniqueness' do
    it 'creates a token' do
      expect(@api_token.create_token.class).to eq(ApiToken)
    end

    it 'regenerates the token if the one generated is not unique' do
      allow(@api_token).to receive(:unique_token?).and_return(false, false, true)
      expect(SecureRandom).to receive(:urlsafe_base64).exactly(3).times.and_return(Time.now.to_s)
      @api_token.create_token
    end

    it 'sanitizes the notes field' do
      note = 'FooBar'
      result = @api_token.create_token(notes: note)
      # TODO: fix this sanitization:
      #expect(result[:notes]).to eq(ActiveRecord::Base.sanitize(note))
      expect(result[:notes]).to eq(note)
    end

    it 'returns true if a token is unique' do
      expect(@api_token.unique_token?(Time.now.utc.iso8601.to_s)).to be_truthy
    end

    it 'returns false is a token is not unique' do
      token = @api_token.create_token
      expect(@api_token.unique_token?(token[:token])).to be_falsey
    end

    it 'defaults to true for active' do
      token = @api_token.create_token
      expect(token[:active]).to be_truthy
    end

    it 'allows an inactive token to be created' do
      token = @api_token.create_token(active: false)
      expect(token[:active]).to be_falsey
    end

    it 'raises an ArgumentError if active is not a boolean' do
      expect { @api_token.create_token(active: 'sql_inject') }.to raise_error(ArgumentError)
    end

    it 'checks uniqueness and safety when creating a token' do
      expect(@api_token).to receive(:unique_token?).at_least(:once).and_return(true)
      expect(@api_token).to receive(:token_looks_safe?).at_least(:once).and_return(true)
      @api_token.create_token
    end
  end

  describe 'token safety' do
    it 'marks a token unsafer when certain sql words are present' do
      unsafe_words = %w('select', 'Delete', 'drOP', 'INSERT', 'into', 'from', 'update')
      unsafe_words.each do |word|
        test_token = SecureRandom.urlsafe_base64(36) + word
        expect(@api_token.token_looks_safe?(test_token)).to be_falsey
      end
    end

    it 'makes sure the took looks safe when checking uniqueness' do
      expect(@api_token).to receive(:token_looks_safe?).at_least(:once).and_return(true)
      @api_token.unique_token?(Time.now.utc.iso8601.to_s)
    end
  end

  describe 'decomissioning a token' do
    it 'decomissions a token' do
      token = @api_token.create_token
      expect(token[:active]).to be_truthy
      result = @api_token.decomission_token(token[:token])
      expect(result[:active]).to be_falsey
    end

    it 'raises an ArgumentError if the token does not exist' do
      expect { @api_token.decomission_token(Time.now.utc.iso8601.to_s) }.to raise_error(ArgumentError)
    end

    it 'raises an Argument Error if the token looks unsafe' do
      allow(@api_token).to receive(:token_looks_safe?).and_return(false)
      expect { @api_token.decomission_token('foo') }.to raise_error(ArgumentError)
    end
  end
  describe 'token validation' do
    it 'validates a token that exists' do
      test_token = @api_token.create_token[:token]
      expect(@api_token.valid_token?(test_token)).to be_truthy
    end
    it 'rejects a token that does not exist' do
      expect(@api_token.valid_token?('vader')).to be_falsey
    end
    it 'rejects a token that does not look SQL sanitized' do
      expect(@api_token.valid_token?('select')).to be_falsey
    end
    it 'rejects a token that exists but is inactive' do
      test_token = @api_token.create_token[:token]
      @api_token.decomission_token(test_token)
      expect(@api_token.valid_token?(test_token)).to be_falsey
    end
  end
end
