require "bundler/capistrano"

server "passauth.net", :web, :app, :db, primary: true

set :application, "pass-server"
set :user, "deployer"
set :deploy_to, "/home/#{user}/apps/#{application}"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, "git"
set :repository, "git@jamesbrennan.ca:jamesbrennan/#{application}.git"
set :branch, "master"

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup" # keep only the last 5 releases

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/redis_#{application} #{command}"
      run "/etc/init.d/node_#{application} #{command}"
      run "/etc/init.d/unicorn_#{application} #{command}"
    end
  end

  desc "Refresh shared node_modules symlink to current node_modules"
  task :refresh_symlink do
    run "rm -rf #{current_path}/realtime/node_modules && ln -s #{shared_path}/realtime/node_modules #{current_path}/realtime/node_modules"
  end
 
  desc "Install node modules non-globally"
  task :npm_install do
    run "cd #{current_path}/realtime && npm install"
  end
  after "deploy:update_code", "deploy:refresh_symlink", "deploy:npm_install"

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
    sudo "ln -nfs #{current_path}/config/node_init.sh /etc/init.d/node_#{application}"
    sudo "ln -nfs #{current_path}/config/redis_init.sh /etc/init.d/redis_#{application}"
    sudo "ln -nfs #{current_path}/config/unicorn_init.sh /etc/init.d/unicorn_#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.yml"), "#{shared_path}/config/database.yml"
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

namespace :deploy do
  namespace :assets do
    task :precompile, :roles => assets_role, :except => { :no_release => true } do
      run <<-CMD.compact
        cd -- #{latest_release.shellescape} &&
        #{rake} RAILS_ENV=#{rails_env.to_s.shellescape} #{asset_env} assets:precompile
      CMD
    end
  end
end