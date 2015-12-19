# Rakefile
require 'sinatra/activerecord/rake'

namespace :db do
  task :load_config do
    require './switchyard.rb'
  end
end

namespace :setup do
  # Copies all files in /config that end with .example.yml to /config as .yml
  # Does not replace file if it already exists
  task :configs do
    directory = 'config/'
    extension_to_remove = '.example.yml'
    extension_to_add = '.yml'
    Dir["#{directory}*#{extension_to_remove}"].each do |filename|
      new_filename = filename[0..filename.length - extension_to_remove.length - 1] + extension_to_add
      FileUtils.cp(filename, new_filename) unless File.exist?(new_filename)
    end
  end
end

# Rake tasks for generating and decomissioning tokens
namespace :tokens do
  require './switchyard.rb'

  # This task generates and displays a new token and prints the result to console
  # @param [String] :notes (default: 'none') Any notes to add to the token
  # @param [Boolean] :active (default: true) If set to true the API key is usable, false it is not
  # @raise [ArgumentError] For a variety of cases when :notes or :active is invalid, exception will contain details
  task :create_token, [:notes,:active] do |t,args|
    token = ApiToken.new.create_token(active: args[:active] || true, notes: args[:notes] || 'none')
    puts token.inspect
  end

  task :decomission_token, [:token_key] do |t,args|
    token = ApiToken.new.decomission_token(args[:token_key])
    puts token.inspect
  end
end
