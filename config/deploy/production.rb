set :application, 'switchyard'
set :repo_url, ENV['REPO'] || 'https://github.com/avalonmediasystem/avalon-switchyard.git'
ask :branch, ENV['SCM_BRANCH'] || `git rev-parse --abbrev-ref HEAD`.chomp
set :deploy_to, ENV['DEPLOY_TO'] || '/var/www/switchyard'
set :environment, ENV['RAILS_ENV'] || 'production'
set :env, fetch(:environment)
set :bundle_without, ENV['RAILS_ENV'] == "development" ? "production" : 'development test debug'

server ENV['HOST'], user: ENV['DEPLOY_USER'], roles: %w(web db app)
