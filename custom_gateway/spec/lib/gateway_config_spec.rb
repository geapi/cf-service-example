require 'spec_helper'

describe GatewayConfig do

  it 'should read config' do
    gw_config = GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_config.yml'), __FILE__))

    gw_config.config.should_not be_empty
    gw_config.config.each_key { | k | k.should be_a Symbol }
    gw_config.service_config.should_not be_empty
    gw_config.service_config.each_key { |k| k.should be_a Symbol }
  end

  it 'raises if v2 and missing service auth token' do
    expect {
      GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_no_service_auth_token.yml'), __FILE__))
    }.to raise_exception
  end

  it 'raises if v2 and service auth token not a hash' do
    expect {
      GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_no_service_auth_token_hash.yml'), __FILE__))
    }.to raise_exception
  end

  it 'raises if v2 and service auth token has more than 1 entry' do
    expect {
      GatewayConfig.new(File.expand_path(File.join('..', '..', 'fixtures', 'gateway_bad_service_auth_token_hash.yml'), __FILE__))
    }.to raise_exception
  end
end