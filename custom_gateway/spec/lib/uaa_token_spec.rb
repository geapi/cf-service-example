require 'spec_helper'

describe UAAToken do
  before do
    uaa_token.stub(:logger).and_return(double.as_null_object)
  end

  let (:uaa_token) do
    gateway_config = GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_config.yml'), __FILE__))
    UAAToken.new(gateway_config.config)
  end

  describe 'uaa_client_token' do
    it 'receives a token' do
      mock_token_issuer = double
      mock_token_grant = double(:info => {'token_type' => 'bearer', 'access_token' => 'e72e16c7e42f292c6912e7710c838347ae178b4a', 'expires_in' => '1234'})
      CF::UAA::TokenIssuer.stub(:new).and_return(mock_token_issuer)
      mock_token_issuer.stub(:implicit_grant_with_creds).and_return(mock_token_grant)
      token = uaa_token.get_client_auth_token

      token.should eq 'bearer e72e16c7e42f292c6912e7710c838347ae178b4a'
    end

    it 'raises if it cannot contact uaa' do
      stub_request(:post, /.*uaa.example.com.*/).to_timeout

      expect {
        uaa_token.get_client_auth_token
      }.to raise_exception(Timeout::Error)
    end
  end

end