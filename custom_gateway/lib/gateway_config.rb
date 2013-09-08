require 'vcap/common'

class GatewayConfig
  attr_reader :config, :service_config

  def initialize(config_filename)
    config_file = default_config_file(config_filename)

    config = YAML.load_file(config_file)
    config = VCAP.symbolize_keys(config)

    @config = parse_config(config)
    @service_config = @config[:service]
  end

  def default_config_file (config_filename)
    return config_filename if File.file?(config_filename)
    config_base_dir = ENV["CLOUD_FOUNDRY_CONFIG_PATH"] || File.join(File.dirname(__FILE__), '..', 'config')
    File.join(config_base_dir, config_filename)
  end

  private
  def parse_config(config)
    cc_api_version = config[:cc_api_version] || "v2"

    if cc_api_version == "v1"
      token = config[:token]
      raise "Token missing" unless token
      raise "Token must be a String or Int, #{token.class} given" unless (token.is_a?(Integer) || token.is_a?(String))
      config[:token] = token.to_s
    else
      service_auth_tokens = config[:service_auth_tokens]
      raise "Service auth token missing" unless service_auth_tokens
      raise "Token must be hash of the form: label_provider => token" unless service_auth_tokens.is_a?(Hash)

      # Each gateway only handles one service, so service_auth_tokens is expected to have just 1 entry
      raise "Unable to manage multiple services" unless service_auth_tokens.size == 1

      # Used by legacy services for validating incoming request (and temporarily for handle fetch/update v1 api)
      config[:token] = service_auth_tokens.values[0].to_s # For legacy services
    end

    config
  end

end