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

# A fairly basic class for generating and decomissioning API tokens that grant access to Avalon Switchyard
class ApiToken < ActiveRecord::Base
  # Creates an unique token and adds it to the database
  #
  # @param [String] notes (default: 'none') Information on the purpose of the token
  # @param [Boolean] active (default: true)  Whether or not the token can be used for API access
  # @raise [ArgumentError] Raised if active is not a Boolean
  # @return [ApiToken] The token created, items can be accessed as symbols. :notes, :active, etc
  def create_token(notes: 'none', active: true)
    # Prevent SQL Injection
    # TODO: fix this sanitization:
    #notes = ActiveRecord::Base.sanitize(notes)
    fail ArgumentError, "active is a #{active.class} not a Boolean" if active != !!active

    token = generate_token
    ApiToken.create(token: token, creation_time: Time.now.utc.iso8601, active: active, notes: notes)
  end

  # Makes a token inactive (unusable for API calls)
  # This does not delete the token, just marks it inactive in the database
  #
  # @raise [ArgumentError] Raised if the token was not found in the database
  # @raise [ArgumentError] Raised if the token looks unsafe (potential SQL inject)
  # @return [ApiToken] The token as it now appears in the database
  def decomission_token(token)
    fail ArgumentError, "#{token} looks unsafe" unless token_looks_safe?(token)
    row = ApiToken.find_by token: token
    fail ArgumentError, "#{token} not found" if row.nil?
    row.update(active: false)
    row
  end

  # Checks to see if the token generated is unique
  #
  # @param [String] token The token to check uniqueness of
  # @raise [ArgumentError] Raised if the token looks unsafe
  # @return [Boolean] true or false
  def unique_token?(token)
    fail ArgumentError, 'The token looks unsafe' unless token_looks_safe?(token)
    result = ApiToken.find_by token: token
    result.nil?
  end

  # Checks to see if the token is a valid new token
  # tests for uniqueness and lack of certain sql keywords
  #
  # @param [String] token the token
  # @return [Boolean] True or False
  def valid_new_token?(token)
    unique_token?(token) && token_looks_safe?(token)
  end

  # Checks to see if the supplied token is a current active token
  def valid_token?(token)
    return false unless !token.nil? && token_looks_safe?(token)
    result = ApiToken.find_by(token: token)
    !result.nil? && result[:active]
  end

  # Checks to see if the token lacks certain sql keywords
  #
  # @param [String] token the token
  # @param [Boolean] True or False
  def token_looks_safe?(token)
    unsafe_words = %w('select', 'delete', 'drop', 'insert', 'into', 'from', 'update')
    downcase_token = token.downcase
    unsafe_words.each do |word|
      return false if downcase_token.include?(word)
    end
    true
  end

  # Generates a random api token, checks for uniqueness and certain sql keywords
  # @param [length] Int (Default: 36) The length of the token
  # @return [String] The token
  def generate_token(n: 36)
    token = nil
    loop do
      token = SecureRandom.urlsafe_base64(n)
      return token if valid_new_token?(token)
    end
  end
end
