
#
# Recipe sturfee::apiserv
#
# _vp_ 20151228, 20160329
#

search(:apps).each do |any_app|
  node.roles.each do |role|
    if any_app['id'] == role
      app = data_bag_item 'apps', any_app['id']
      if app['type'][app['id']].include? 'apiserv'
        puts! "sturfee::apiserv, deploying #{role}"

        ## config
        user                = app['user'][node.chef_environment]
        projects_dir        = "/home/#{user}/projects"
        app['deploy_to']    = "#{projects_dir}/#{app['id']}"
        upstart_script_name = "#{app['id']}-app"
        domain              = app['domains'][node.chef_environment][0]
        region              = app['s3'][node.chef_environment]['region']
        s3_key              = app['s3'][node.chef_environment]['key']
        s3_secret           = app['s3'][node.chef_environment]['secret']
        s3_deploy_bucket    = app['s3'][node.chef_environment]['buckets']['deploy']


        app['packages'].each do |pkg, version|
          package pkg
        end

        # execute "unlock staticserv file" do
        #   command "service #{upstart_script_name} stop ; sleep 3 ; pkill staticserv ; echo ok"
        # end

        ##
        ## create all the directories
        ##
        directory "#{app['deploy_to']}/config/letsencrypt/live/#{domain}" do
          action :create
          recursive true
          owner user
          group user
        end

        # create deploy wrapper
        ruby_block "write_key" do
          block do
            f = ::File.open("#{projects_dir}/id_deploy", "w")
            f.print(app["deploy_key"])
            f.close
          end
          not_if do ::File.exists?("#{projects_dir}/id_deploy"); end
        end
        file "#{projects_dir}/id_deploy" do
          owner user
          group user
          mode '0600'
        end
        template "#{projects_dir}/deploy-ssh-wrapper" do
          source "deploy-ssh-wrapper.erb"
          owner user
          group user
          mode "0755"
          variables({
                      :deploy_to => projects_dir # this is only for reference of id_deploy file.
                    })
        end
        
        ## configure the api endpoint
        # template "#{app['deploy_to']}/current/public/js/config.js" do
        #   source "app/public/js/config.js.erb"
        #   owner user
        #   group user
        #   mode "0664"
        #   variables(
        #     :endpoint => app['api_endpoint']
        #   )
        # end
                
        # service "#{app['id']}-app" do
        #   action :reload
        # end

        ## get the executable server
        execute 'get the executable server' do
          command %{AWS_ACCESS_KEY_ID=#{s3_key} AWS_SECRET_ACCESS_KEY=#{s3_secret} aws s3 cp s3://#{s3_deploy_bucket}/apiserv/latest/apiserv apiserv --region #{region}}
          cwd "#{app['deploy_to']}"
        end
        file "#{app['deploy_to']}/apiserv" do
          mode '0755'
        end

        ## write staticserv config
        template "#{app['deploy_to']}/config/apiserv.json" do
          source "app/config/apiserv.json.erb"
          variables({
            :domain        => domain,
            :db_user       => app['mysql_db_user'][node.chef_environment],
            :db_university => app['mysql_db_university'][node.chef_environment],
            :s3            => app['s3'][node.chef_environment],
            :mailer        => app['mailer'][node.chef_environment],
            :fb            => app['facebook'][node.chef_environment]
          })
        end

        ##
        ## write ssl pem files
        ##
        ruby_block "write_ssl_fullchain" do
          block do
            f = ::File.open("#{projects_dir}/config/letsencrypt/live/#{domain}/fullchain.pem", "w")
            f.print(app["letsencrypt"][node.chef_environment]['fullchain'])
            f.close
          end
        end
        file "#{projects_dir}/config/letsencrypt/live/#{domain}/fullchain.pem" do
          owner user
          group user
          mode '0600'
        end
        ruby_block "write_ssl_privkey" do
          block do
            f = ::File.open("#{projects_dir}/config/letsencrypt/live/#{domain}/privkey.pem", "w")
            f.print(app["letsencrypt"][node.chef_environment]['privkey'])
            f.close
          end
        end
        file "#{projects_dir}/config/letsencrypt/live/#{domain}/privkey.pem" do
          owner user
          group user
          mode '0600'
        end

        ##
        ## service
        ##
        template "/etc/init/#{upstart_script_name}.conf" do
          source "etc/init/upstart_serv.conf.erb"
          owner  "root"
          group  "root"
          mode   "0664"
          variables(
            :app_name        => app['id'],
            :app_root        => "#{app['deploy_to']}/current",
            :executable_name => 'apiserv'
          )
        end
        service upstart_script_name do
          provider Chef::Provider::Service::Upstart
          supports :status => true, :restart => true
          action [ :enable, :start ]
        end

      end
    end
  end
end






