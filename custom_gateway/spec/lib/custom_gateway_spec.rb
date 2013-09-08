require_relative '../spec_helper'

describe 'Custom Gateway' do
  it 'should respond to GET' do
    get '/health'
    last_response.should be_ok
    last_response.body.should match(/The custom gateway is up!/)
  end

  it 'accepts provision requests' do
    req = VCAP::Services::Api::GatewayProvisionRequest.new(unique_id: 'uid0', name: 'instance0')
    post '/gateway/v1/configurations', req.encode, 'CONTENT-TYPE' => 'application/json'

    last_response.should be_ok
    rsp = VCAP::Services::Api::GatewayHandleResponse.decode(last_response.body)
    rsp.service_id.should == 'sid0'
  end

  it 'accepts bind requests' do
    ENV['VCAP_APPLICATION'] = '{"application_users":[],"instance_id":"7d9f5627d9d60f4985c412a5e1b7a124","instance_index":0,"application_version":"431e3510-4266-4053-9648-0b19ed05afba","application_name":"custom-gateway","application_uris":["custom-gateway.custom.example.org"],"started_at":"2013-07-12 00:00:30 +0000","started_at_timestamp":1373587230,"host":"0.0.0.0","port":63971,"limits":{"mem":128,"disk":1024,"fds":16384},"version":"431e3510-4266-4053-9648-0b19ed05afba","name":"custom-gateway","uris":["custom-gateway.custom.example.org"],"users":[],"start":"2013-07-12 00:00:30 +0000","state_timestamp":1373587230}'
    req = VCAP::Services::Api::GatewayBindRequest.new(service_id: 'sid0', label: 'pg-1.0', email: 'user@cf.org', binding_options: {})
    post '/gateway/v1/configurations/sid0/handles', req.encode, 'CONTENT-TYPE' => 'application/json'

    last_response.should be_ok
    rsp = VCAP::Services::Api::GatewayHandleResponse.decode(last_response.body)
    rsp.service_id.should == 'hid0'
    rsp.credentials["url"].should == "http://custom-gateway-service.custom.example.org/CustomWorksAPI/api"
  end
end