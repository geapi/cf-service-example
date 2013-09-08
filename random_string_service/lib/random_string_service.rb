require 'sinatra'

class RandomStringService < Sinatra::Base
  get '/health' do
    "The random string service is at your service!"
  end

  get '/random_string/:length' do
    length = params[:length] || 100

    (0...length.to_i).map{ ('a'..'z').to_a[rand(26)] }.join
  end

  configure :production do
    enable :logging
  end

  configure :test, :development do

  end

  def request_body
    request.body.rewind
    request.body.read
  end
end

