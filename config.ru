require 'rubygems'
require 'sinatra'
require File.expand_path '../switchyard.rb', __FILE__

$log = Logger.new '/var/www/switchyard/production.log'
$log.level = Logger::WARN
$log.datetime_format = '%Y-%m-%d %H:%M:%S%z '
RestClient.log = $log

run Sinatra::Application
