# Rakefile
require 'dotenv/tasks'
require 'sinatra/activerecord/rake'

namespace :db do
  task :load_config do
    require './switchyard.rb'
  end

  # Deletes all rows in collections and media_objects
  # @example Clear collections and media_objects table
  # RACK_ENV=env bundle exec rake db:clear_history
  task :clear_history do
    require './switchyard.rb'
    MediaObject.delete_all
    Collection.delete_all
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

namespace :switchyard do
  task :send_item => :dotenv do
    unless Router.new.send_in_progress?
      # Find the oldest object
      obj = Objects.new.oldest_ready_object
      unless obj.nil?
        # Lock it so future chron tasks don't run
        media_object = MediaObject.find(obj[0])
        media_object.locked = true
        media_object.last_modified = Time.now.utc.iso8601.to_s
        media_object.save!


        # Send It
        new_object = media_object.avalon_pid.nil?
        begin
          item = Objects.new(posted_content: media_object.api_hash)
          object = item.parse_request_body
          item.post_new_media_object(object) if new_object
          item.update_media_object(object) unless new_object
        rescue Exception => e
          media_object.error = true
          media_object.status = 'error'
          media_object.message = e
          media_object.save!
        end

        media_object.locked = false
        media_object.save!
      end
    end
  end

  task :send_batch => :dotenv do
    unless Router.new.send_in_progress?
      # Find the oldest object
      objs = MediaObject.where(status: 'received')
      unless objs.empty?
        objs.each do |obj|
          # Lock it so future chron tasks don't run
          media_object = MediaObject.find(obj[0])
          media_object.locked = true
          media_object.last_modified = Time.now.utc.iso8601.to_s
          media_object.save!


          # Send It
          new_object = media_object.avalon_pid.nil?
          begin
            item = Objects.new(posted_content: media_object.api_hash)
            object = item.parse_request_body
            item.post_new_media_object(object) if new_object
            item.update_media_object(object) unless new_object
          rescue Exception => e
            media_object.error = true
            media_object.status = 'error'
            media_object.message = e
            media_object.save!
          end

          media_object.locked = false
          media_object.save!
        end
      end
    end
  end
end
