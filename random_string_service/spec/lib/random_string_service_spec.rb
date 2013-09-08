require_relative "../spec_helper"

describe "Random String Service" do
  it "responds to GET" do
    get "/health"

    expect(last_response).to be_ok
    expect(last_response.body).to eq("The random string service is at your service!")
  end

  it "returns a random string of the given length" do
    get "/random_string/25"

    expect(last_response).to be_ok
    expect(last_response.body).to match(/[a-z]{25}/)
    expect(last_response.body).to_not match(/[a-z]{26}/)
  end
end