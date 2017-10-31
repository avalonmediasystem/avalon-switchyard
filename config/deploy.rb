# config valid only for current version of Capistrano
# lock '3.4.0'


# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'

# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w(config/database.yml config/units.yml config/switchyard.yml config/avalons.yml)


# set :linked_files, fetch(:linked_files, []).push('config/database.yml')
# set :linked_files, fetch(:linked_files, []).push('config/units.yml')
# set :linked_files, fetch(:linked_files, []).push('config/switchyard.yml')
# set :linked_files, fetch(:linked_files, []).push('config/avalons.yml')

# Default value for linked_dirs is []
# set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do
  desc 'Make public dir for passenger'
  task :passenger_dir do
    on roles(:app) do
      execute :mkdir, release_path.join('public')
    end
  end

  desc 'Restart application and run db migrations'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute "cd '#{release_path}'; RACK_ENV=#{fetch(:env)} bundle exec rake db:migrate"
      execute :mkdir, release_path.join('tmp')
      execute :touch, release_path.join('tmp/restart.txt')
      execute "cd '#{release_path}'; cp config/.env.production .env" if fetch(:env) == 'production'
    end
  end

  before :publishing, :passenger_dir
  #before :publishing, :migrate
  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
       # Here we can do anything such as:
       # within release_path do
       #   execute :rake, 'cache:clear'
       # end
    end
  end
end
