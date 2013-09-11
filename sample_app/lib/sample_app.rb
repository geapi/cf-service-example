require "sinatra"
require "net/http"
require "json"

class SampleApp < Sinatra::Base
  get "/health" do
    "The sample app is up!"
  end

  get "/" do
    random_string = ::Net::HTTP.get(URI("#{random_string_service_url}/random_string/66"))
    <<-HTML
<center>
<h2>Random String</h2>
<p>#{random_string}</p>
<p><b>Reload, to see a new one.</b></p>
</center>
    HTML
  end

  def random_string_service_url
    unless ENV["VCAP_SERVICES"]
      return "http://random-string-service-service.georg.cf-app.com/random_string"
    end

    vcap_services = JSON.parse(ENV["VCAP_SERVICES"])
    vcap_services["random-string-service-1.0"][0]["credentials"]["url"]
  end
end