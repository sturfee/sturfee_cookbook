
#
# Recipe sturfee::staticserv
#
# _vp_ 20151228, 20160329
#

search(:apps).each do |any_app|
  node.roles.each do |role|
    if any_app['id'] == role
      app = data_bag_item 'apps', any_app['id']
      if app['type'][app['id']].include? 'staticserv'
        puts! "sturfee::staticserv, deploying #{role}"

        ## config
        user = app['user'][node.chef_environment]
        projects_dir = "/home/#{user}/projects"
        app['deploy_to'] = "#{projects_dir}/#{app['id']}"
        upstart_script_name = "#{app['id']}-app"
        
        app['packages'].each do |pkg, version|
          package pkg
        end

        execute "unlock staticserv file" do
          command "service #{upstart_script_name} stop ; sleep 3 ; pkill staticserv ; echo ok"
        end

        directory projects_dir do
          action :create
          recursive true
          owner user
          group user
        end

        # deploy resource
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
        
        #
        # deploy resource
        #
        deploy_revision app['id'] do
          revision     app['revision'][node.chef_environment]
          repository   app['repository']
          user         user
          group        user
          deploy_to    app['deploy_to']
          environment  'RAILS_ENV' => app['rack_environment']
          action        app['force'][node.chef_environment] ? :force_deploy : :deploy
          ssh_wrapper   "#{projects_dir}/deploy-ssh-wrapper" if app['deploy_key']
          shallow_clone true
          migrate       false
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
                
        service "#{app['id']}-app" do
          action :reload
        end

        ## get the executable server
        execute 'get the executable server' do
          command %{AWS_ACCESS_KEY_ID=#{app['s3_key']} AWS_SECRET_ACCESS_KEY=#{app['s3_secret']} aws s3 cp s3://#{app['s3_bucket']}/staticserv/latest/staticserv staticserv --region us-west-2}
          cwd "#{app['deploy_to']}/current"
        end
        file "#{app['deploy_to']}/current/staticserv" do
          mode '0755'
        end

        ## write staticserv config
        template "#{app['deploy_to']}/current/config/staticserv.json" do
          source "app/config/staticserv.json.erb"
          variables({
            :domain      => app['domains'][node.chef_environment][0],
            :deploy_path => "#{app['deploy_to']}/current"
          })
        end


        ##
        ## service
        ##
        template "/etc/init/#{upstart_script_name}.conf" do
          source "etc/init/upstart.conf.erb"
          owner  "root"
          group  "root"
          mode   "0664"
          variables(
            :app_name       => app['id'],
            :app_root       => "#{app['deploy_to']}/current"
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






