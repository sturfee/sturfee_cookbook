require 'spec_helper'

describe 'sturfee::apiserv' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
      node.set['cookbook']['attribute'] = 'hello'
      node.set['roles'] = [ 'some', 'roles' ]
    end.converge("role[sturfee_apiserv]") # described_recipe
  end
  
  before :each do
    stub_search("apps", "*:*").and_return([{ :id => 'sturfee_apiserv' }])
    @service_name = "sturfee_apiserv-app"
    @projects_dir = "/home/ubuntu/projects"
    stub_data_bag_item("apps", "sturfee_apiserv").and_return(
      'id' => 'sturfee_apiserv',
      'force' => { '_default' => true },
      'type' => { 'sturfee_apiserv' => [ 'apiserv' ] },
      'packages' => {'wget' => ''},
      'user' => { "_default" => "ubuntu" },
      'revision' => { "_default" => "master" }
    )
  end
  
  it 'installs app packages' do
    expect(chef_run).to install_package("wget")
  end
    
  it 'unlocks apiserv file' do
  end

  it 'creates letsencrypt/<DOMAIN> dir' do
  end

  it 'renders deploy wrapper' do
    expect(chef_run).to render_file( "#{@projects_dir}/deploy-ssh-wrapper" )
  end

  it 'gets the executable server' do
  end

  it 'writes static config' do
  end

  it 'writes ssl fullchain' do
  end

  it 'writes ssl privkey' do
  end

  it 'creates upstart service' do
  end
  
  it 'restarts the service at the end of the run' do
    expect(chef_run).to restart_service(@service_name)  
    false.should eql true
  end
  
end
