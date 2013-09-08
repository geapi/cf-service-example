require File.join(File.dirname(__FILE__), '../lib', 'random_string_service.rb')

require 'rack/test'
require 'webmock/rspec'
require 'sinatra'

# setup test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

def app
  RandomStringService
end

RSpec.configure do |config|
  WebMock.disable_net_connect!(:allow_localhost => true)
  config.include Rack::Test::Methods
  config.order = "random"
end