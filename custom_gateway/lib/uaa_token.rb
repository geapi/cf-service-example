require_relative 'gateway_config'
require 'uaa'

class UAAToken
  def initialize(options)
    @options = options
  end

  def get_client_auth_token
    # Load the auth token to be sent out in Authorization header when making CCNG-v2 requests
    credentials = @options.fetch(:uaa_client_auth_credentials)
    client_id = @options.fetch(:uaa_client_id)

    ti = CF::UAA::TokenIssuer.new(@options.fetch(:uaa_endpoint), client_id)
    token = ti.implicit_grant_with_creds(credentials).info
    uaa_client_auth_token = "#{token["token_type"]} #{token["access_token"]}"
    expire_time = token["expires_in"].to_i
    logger.info("Successfully refresh auth token for:\
                #{credentials[:username]}, token expires in \
                #{expire_time} seconds.")

    uaa_client_auth_token
  end

  def logger
    @logger ||= ::Logger.new(STDERR)
  end
end