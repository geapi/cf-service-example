require 'sinatra'
require_relative 'gateway_config'
require_relative 'cloudcontroller_advertiser'
require_relative 'uaa_token'
require_relative 'erb_handler'
require 'open3'

class CustomGateway < Sinatra::Base
  get '/health' do
    "The custom gateway is up!"
  end

  post '/gateway/v1/configurations' do
    req = VCAP::Services::Api::GatewayProvisionRequest.decode(request_body)
    logger.info("Provision request for unique_id=#{req.unique_id}")

    rsp = VCAP::Services::Api::GatewayHandleResponse.new(service_id: 'sid0', configuration: '', credentials: '')
    headers 'Content-Type' => 'application/json'
    body rsp.encode
  end

  post '/gateway/v1/configurations/:service_id/handles' do
    req = VCAP::Services::Api::GatewayBindRequest.decode(request_body)
    logger.info("Bind request for service_id=#{req.service_id}")
    vcap_application = JSON.parse(ENV['VCAP_APPLICATION'])
    url_parts = vcap_application['uris'][0].split(".")
    url_parts[0] = "#{vcap_application['name']}-service"
    url = 'http://' + url_parts.join(".")

    rsp = VCAP::Services::Api::GatewayHandleResponse.new(service_id: 'hid0', configuration: '', credentials: {url: url})
    headers 'Content-Type' => 'application/json'
    body rsp.encode
  end

  configure :production do
    enable :logging
    gw_config = GatewayConfig.new(File.expand_path(File.join('..', '..', 'config', 'gateway_config.yml'), __FILE__))
    config = gw_config.config
    uaa_token = UAAToken.new(config)
    cloudcontroller_advertiser = ::CloudControllerAdvertiser.new(config.fetch(:cloud_controller_uri), uaa_token)
    vcap_application = JSON.parse(ENV['VCAP_APPLICATION'])

    service_config = gw_config.service_config
    service_config[:url] = 'http://' + vcap_application['uris'][0]
    service_config[:label] = vcap_application["name"]
    service_config[:unique_id] = "#{service_config[:label]}-#{service_config[:version]}"
    service_config[:plans].each do |name, p|
      p[:unique_id] = "#{service_config[:unique_id]}-#{name}"
    end
    service_offering = ServiceOffering.new(service_config)

    registered_services = cloudcontroller_advertiser.list_services_with_plans
    cloudcontroller_advertiser.resolve_service(registered_services, service_offering)
    guid = cloudcontroller_advertiser.advertise_service(service_offering)
    cloudcontroller_advertiser.advertise_plans(guid, service_offering.plans)
  end

  configure :test, :development do

  end

  def request_body
    request.body.rewind
    request.body.read
  end
end

