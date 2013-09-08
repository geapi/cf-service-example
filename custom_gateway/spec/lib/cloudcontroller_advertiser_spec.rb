require 'spec_helper'

describe CloudControllerAdvertiser do
  before do
    cloudcontroller_advertiser.stub(:logger).and_return(double.as_null_object)
  end

  let(:cloudcontroller_advertiser) do
    uaa_token = UAAToken.new({})
    uaa_token.stub(:get_client_auth_token).and_return('bearer abcdefgh1234')
    CloudControllerAdvertiser.new("http://cc.example.com", uaa_token)
  end

  describe 'list_services' do
    it 'gets to the correct endpoint' do
      stub_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").to_return(status: 200, body: '{"total_results": 0}')
      cloudcontroller_advertiser.list_services_with_plans

      a_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").should have_been_requested
    end

    it 'sends and authorization header with the uaa token' do
      stub_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").to_return(status: 200, body: '{"total_results": 0}')
      cloudcontroller_advertiser.list_services_with_plans

      a_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").
        with(:headers => {'Authorization' => 'bearer abcdefgh1234'}).
        should have_been_requested
    end

    it 'gets the list of known services' do
      body = File.open(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_list_services.json'), __FILE__)) { |f| f.read }
      stub_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").to_return(status: 200, body: body)
      services = cloudcontroller_advertiser.list_services_with_plans

      a_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").should have_been_requested
      parsed = JSON.parse(body, :symbolize_names => true)
      services.size.should eql parsed[:resources].size
    end

    it 'gets the list of associated plans' do
      plan_counts = {"17523a3a-44fe-4c59-a962-af6cd06e0f92" => 1, "ec01ff18-1680-4eb9-aa77-cc5a6eadddb3" => 0, "pg-1.0" => 1}
      body = File.open(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_list_services.json'), __FILE__)) { |f| f.read }
      stub_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").to_return(status: 200, body: body)
      services = cloudcontroller_advertiser.list_services_with_plans

      a_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").should have_been_requested
      services.each { |s|
        s.plans.size.should eql plan_counts[s['unique_id']]
      }
    end

    it 'raises if it cannot contact the cloud controller' do
      stub_request(:get, "http://cc.example.com/v2/services?inline-relations-depth=2").to_timeout

      expect {
        cloudcontroller_advertiser.list_services_with_plans
      }.to raise_exception(Timeout::Error)
    end
  end

  describe 'resolve_service' do
    before() do
      plan = {guid: 'pguid0', unique_id: 'puid0', description: 'desc', free: false, extra: ''}
      service = ServiceOffering.new(name: 'name', guid: 'guid0', unique_id: 'uid0', version: '1.0', provider: 'aws', url: 'http://example.com', description: 'desc', plans: {'plan1' => plan})
      @registered_services = [service]
    end

    it 'adds a guid to a matching registered service' do
      service = ServiceOffering.new(name: 'name', unique_id: 'uid0', version: '1.0', provider: 'aws', url: 'http://example.com', description: 'desc')
      resolved_service = cloudcontroller_advertiser.resolve_service(@registered_services, service)

      resolved_service.guid.should eql 'guid0'
    end

    it 'no guid is added when no registered service exists' do
      service = ServiceOffering.new(name: 'name', unique_id: 'uid1', version: '1.0', provider: 'aws', url: 'http://example.com', description: 'desc')
      resolved_service = cloudcontroller_advertiser.resolve_service(@registered_services, service)

      resolved_service.should be_nil
      service.guid.should be_nil
    end

    it 'adds a plan guid when a matching registered plan exists' do
      plan = {unique_id: 'puid0', description: 'desc', free: false, extra: ''}
      service = ServiceOffering.new(name: 'name', unique_id: 'uid0', version: '1.0', provider: 'aws', url: 'http://example.com', description: 'desc', plans: {'plan1' => plan})
      resolved_service = cloudcontroller_advertiser.resolve_service(@registered_services, service)

      resolved_service.plans[0]['guid'].should eql 'pguid0'
    end

    it 'no guid is added when there is no matching plan' do
      plan = {unique_id: 'puid1', description: 'desc', free: false, extra: ''}
      service = ServiceOffering.new(name: 'name', unique_id: 'uid0', version: '1.0', provider: 'aws', url: 'http://example.com', description: 'desc', plans: {'plan1' => plan})
      resolved_service = cloudcontroller_advertiser.resolve_service(@registered_services, service)

      resolved_service.plans[0]['guid'].should be_nil
    end
  end

  describe 'advertise_service' do
    before() do
      stub_request(:post, "http://cc.example.com/v2/services").to_return(status: 200, body: {metadata: {guid: "666-999"}}.to_json, headers: [])
      config = GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_config.yml'), __FILE__))
      config.service_config[:url] = 'http://cc.example.com'
      @service_offering = ServiceOffering.new(config.service_config)
    end

    it 'posts to the correct endpoint' do
      cloudcontroller_advertiser.advertise_service(@service_offering)

      a_request(:post, "http://cc.example.com/v2/services").should have_been_requested
    end

    it 'sends an authorization header with the uaa client token' do
      cloudcontroller_advertiser.advertise_service(@service_offering)

      a_request(:post, "http://cc.example.com/v2/services").
        with(:headers => {'Authorization' => 'bearer abcdefgh1234'}).
        should have_been_made
    end

    it 'sends the correct payload' do
      guid = cloudcontroller_advertiser.advertise_service(@service_offering)

      a_request(:post, "http://cc.example.com/v2/services").
        with(:body => JSON.generate(@service_offering.to_hash), :headers => {'Content-Type' => 'application/json'}).
        should have_been_made
      guid.should eql @service_offering.guid
    end

    it 'updates when already registered' do
      stub_request(:put, "http://cc.example.com/v2/services/666-999").to_return(:status => 200, body: {metadata: {guid: "666-999"}}.to_json, :headers => {})

      @service_offering.guid = "666-999"
      service_data = @service_offering.to_hash
      service_data.delete('unique_id')
      cloudcontroller_advertiser.advertise_service(@service_offering)
      a_request(:put, "http://cc.example.com/v2/services/666-999").
        with(:body => JSON.generate(service_data.to_hash), :headers => {'Content-Type' => 'application/json'}).
        should have_been_made
    end

    it 'raises if it cannot contact cloudcontroller' do
      stub_request(:post, "http://cc.example.com/v2/services").to_timeout

      expect {
        cloudcontroller_advertiser.advertise_service(@service_offering)
      }.to raise_exception(Timeout::Error)
    end
  end

  describe 'advertise_plan' do
    before() do
      stub_request(:post, "http://cc.example.com/v2/service_plans").to_return(:status => 200, :body => {metadata: {guid: "666-999"}}.to_json)
      config = GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_config.yml'), __FILE__))
      config.service_config[:url] = 'http://cc.example.com'
      @service_guid = 'abcd-1234'
      @service_plans = ServiceOffering.new(config.service_config).plans
    end

    it 'posts to the correct endpoint' do
      cloudcontroller_advertiser.advertise_plans(@service_guid, @service_plans)

      a_request(:post, "http://cc.example.com/v2/service_plans").should have_been_made
    end

    it 'sends an authorization header with the uaa client token' do
      cloudcontroller_advertiser.advertise_plans(@service_guid, @service_plans)

      a_request(:post, "http://cc.example.com/v2/service_plans").
        with(:headers => {'Authorization' => 'bearer abcdefgh1234'}).
        should have_been_made
    end

    it 'sends the correct payload' do
      cloudcontroller_advertiser.advertise_plans(@service_guid, @service_plans)

      plan = @service_plans[0].clone
      plan.delete('guid')
      a_request(:post, "http://cc.example.com/v2/service_plans").
        with(:body => Yajl::Encoder.encode(plan), :headers => {'Content-Type' => 'application/json'}).
        should have_been_made
      @service_plans[0]['service_guid'].should eql @service_guid
      @service_plans[0]['guid'].should eql '666-999'
    end

    it 'update already registered plan' do
      stub_request(:put, "http://cc.example.com/v2/service_plans/666-999").to_return(:status => 200, :body => {metadata: {guid: "666-999"}}.to_json, :headers => {})

      @service_plans[0]['guid'] = "666-999"
      cloudcontroller_advertiser.advertise_plans(@service_guid, @service_plans)
      plan = @service_plans[0].clone
      plan.delete('unique_id')
      plan.delete('guid')
      a_request(:put, "http://cc.example.com/v2/service_plans/666-999").
        with(:body => Yajl::Encoder.encode(plan), :headers => {'Content-Type' => 'application/json'}).
        should have_been_made
    end

    it 'raises if it cannot contact cloudcontroller' do
      stub_request(:post, "http://cc.example.com/v2/service_plans").to_timeout

      expect {
        cloudcontroller_advertiser.advertise_plans(@service_guid, @service_plans)
      }.to raise_exception
    end
  end
end
