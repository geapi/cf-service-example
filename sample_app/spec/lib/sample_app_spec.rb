require_relative "../spec_helper"
require "net/http"

describe "Sample App" do
  it "responds to GET/health" do
    get "/health"

    expect(last_response).to be_ok
    expect(last_response.body).to match(/The sample app is up!/)
  end

  it "puts a random string out" do
    ::Net::HTTP.stub(:get).and_return("random string")
    get "/"

    expect(last_response).to be_ok
    expect(last_response.body).to match(/.*random string.*/)
  end
end