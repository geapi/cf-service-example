require 'net/http'
require 'uri'
require 'json'
require 'services/api'
require 'yajl'
require 'logger'
require_relative 'service_offering'

class CloudControllerAdvertiser
  attr_reader :cloudcontroller_uri, :offering_path, :service_plans_path

  def initialize(cloudcontroller_url, uaa_token)
    @cloudcontroller_uri = URI.parse(cloudcontroller_url)
    @offering_path = "/v2/services"
    @service_plans_path = "/v2/service_plans"
    @service_list_path = "/v2/services?inline-relations-depth=2"
    @uaa_token = uaa_token
  end

  def cloudcontroller_req_hdrs
    @cloudcontroller_req_hdrs ||= begin
      {
        'Content-Type' => 'application/json',
        'Authorization' => @uaa_token.get_client_auth_token
      }
    end
  end

  def list_services_with_plans
    http = Net::HTTP.new(cloudcontroller_uri.host, cloudcontroller_uri.port)
    request = Net::HTTP::Get.new(cloudcontroller_uri.merge(@service_list_path).request_uri, cloudcontroller_req_hdrs)

    response = http.request(request)
    if response.kind_of? Net::HTTPSuccess
      parsed_body = JSON.parse(response.body, :symbolize_names => true)
      services = []

      if parsed_body[:total_results] > 0
        parsed_body[:resources].each { |r|
          entity = r[:entity]
          offering = ServiceOffering.new(entity)
          offering.guid = r[:metadata][:guid]

          if entity[:service_plans]
            entity[:service_plans].each { |p|
              plan_metadata = p[:metadata]
              plan_entity = p[:entity]
              service_plan = {'guid' => plan_metadata[:guid]}
              %w(name unique_id description free extra).each { |k| service_plan[k] = plan_entity.fetch(k.to_sym) }

              offering.plans << service_plan
            }
          end

          services << offering
        }
      end
      logger.info("Cloudcontroller Advertiser: List services response (code=#{response.code}): #{parsed_body.inspect}")
    elsif !response.kind_of? Net::HTTPError
      logger.info("Cloudcontroller Advertiser: List services response (code=#{response.code}): #{parsed_body.inspect}")
    else
      logger.error("Cloudcontroller Advertiser: Failed list services: #{service_offering.inspect}, code=#{response.code}")
      raise
    end
    services
  end

  def advertise_service(service_offering)
    service_guid = service_offering.guid
    http = Net::HTTP.new(cloudcontroller_uri.host, cloudcontroller_uri.port)
    service_data = service_offering.to_hash
    if service_guid.nil?
      request = Net::HTTP::Post.new(cloudcontroller_uri.merge(offering_path).request_uri, cloudcontroller_req_hdrs)
    else
      service_path = "#{offering_path}/#{service_guid}"
      request = Net::HTTP::Put.new(cloudcontroller_uri.merge(service_path).request_uri, cloudcontroller_req_hdrs)
      service_data.delete('unique_id')
    end
    request.body = JSON.generate(service_data)

    response = http.request(request)
    if response.kind_of? Net::HTTPSuccess
      parsed_body = JSON.parse(response.body)
      service_guid = parsed_body["metadata"]["guid"]
      service_offering.guid = service_guid
      logger.info("Cloudcontroller Advertiser: Advertise offering response (code=#{response.code}): #{parsed_body.inspect}")
    elsif !response.kind_of? Net::HTTPError
      logger.info("Cloudcontroller Advertiser: Advertise offering response (code=#{response.code}): #{parsed_body.inspect}")
    else
      logger.error("Cloudcontroller Advertiser: Failed advertise offerings:#{service_offering.inspect}, code=#{response.code}")
      raise
    end

    service_guid
  end

  def advertise_plans(service_guid, service_plans)
    service_plans.each { |p|
      p['service_guid'] = service_guid
      plan_data = p.clone()
      http = Net::HTTP.new(cloudcontroller_uri.host, cloudcontroller_uri.port)
      if p['guid']
        request = Net::HTTP::Put.new(cloudcontroller_uri.merge("#{service_plans_path}/#{p['guid']}").request_uri, cloudcontroller_req_hdrs)
        plan_data.delete('unique_id')
        plan_data.delete('public')
        plan_data.delete('guid')
      else
        request = Net::HTTP::Post.new(cloudcontroller_uri.merge(service_plans_path).request_uri, cloudcontroller_req_hdrs)
      end
      request.body = Yajl::Encoder.encode(plan_data)

      response = http.request(request)
      if response.kind_of? Net::HTTPSuccess
        parsed_body = JSON.parse(response.body)
        plan_guid = parsed_body["metadata"]["guid"]
        p['guid'] = plan_guid
        logger.info("Cloudcontroller Advertiser: Advertise plan response (code=#{response.code}): #{parsed_body.inspect}")
      else
        logger.error("Cloudcontroller Advertiser: Failed advertise plan: #{p.inspect}, code=#{response.code})")
      end
    }
  end

  def resolve_service(registered_services, configured_service)
    resolved = nil

    registered_service = registered_services.find { |rs| rs['unique_id'] == configured_service['unique_id'] }
    if registered_service
      configured_service.guid = registered_service.guid
      resolved = configured_service

      configured_service.plans.each { |p|
        registered_plan = registered_service.plans.find { |rp| rp['unique_id'] == p['unique_id'] }
        if registered_plan
          p['guid'] = registered_plan['guid']
        end
      }
    end
    resolved
  end

  private

  def logger
    @logger ||= ::Logger.new(STDERR)
  end

end