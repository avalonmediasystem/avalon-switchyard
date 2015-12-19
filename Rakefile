# Rakefile
require 'sinatra/activerecord/rake'
require 'byebug'

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
