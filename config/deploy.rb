# config/deploy.rb
# require "bundler/capistrano"

set :application,     "stage"
set :scm,             :git
set :repository,      "git@github.com:lkkadiri/ec2test.git"
set :branch,          "order_service"
set :migrate_target,  :current
set :ssh_options,     { :forward_agent => true}

set :user,            "deployer"
set :use_sudo,        false

default_run_options[:pty] = true
set :ssh_options, 		{:auth_methods => "publickey"}
set :ssh_options,			{:keys => ["/Users/leela/Work/AWSKeys/stage-key.pem"]}

set :rails_env,       "production"
set :deploy_to,       "/home/#{user}/apps/#{application}"
set :normalize_asset_timestamps, false

role :web,    "54.245.117.51"
role :app,    "54.245.117.51"
role :db,     "54.245.117.51", :primary => true

set(:latest_release)  { fetch(:current_path) }
set(:release_path)    { fetch(:current_path) }
set(:current_release) { fetch(:current_path) }

set(:current_revision)  { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:latest_revision)   { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:previous_revision) { capture("cd #{current_path}; git rev-parse --short HEAD@{1}").strip }

default_environment["RAILS_ENV"] = 'production'

default_run_options[:shell] = 'bash'

after "deploy", "deploy:cleanup" # keep only the last 5 releases

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end

def run_rake(cmd)
  run "cd #{current_path}; #{rake} #{cmd}"
end