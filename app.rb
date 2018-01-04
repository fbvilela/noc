require 'sinatra'
require 'oauth2'
require 'json'
require 'tidyhqrb'


enable :sessions

CLIENT = ENV['TIDYHQ_CLIENT']
SECRET = ENV['TIDYHQ_SECRET']

def oauth_client
  client ||= OAuth2::Client.new(CLIENT, SECRET, {
    :site => 'https://accounts.tidyhq.com',
    :authorize_url => "/oauth/authorize",
    :token_url => "/oauth/token"
  })
end

def tidyhq
  Tidyhqrb::Client.auth_token = ENV['TIDYHQ_ACCESS_CODE'] if ENV['TIDYHQ_ACCESS_CODE']
  tidyhq_client ||= Tidyhqrb::Client.new
end

get '/' do
  erb :index
end

get '/products.json' do
  content_type :json
  tidyhq.products.all.to_json
end

get "/auth" do
  redirect oauth_client.auth_code.authorize_url(:redirect_uri => redirect_uri)
end

get '/callback' do
  access_token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
  session[:access_token] = access_token.token
  @message = "Successfully authenticated with the server"
  @access_token = session[:access_token]
  Tidyhqrb::Client.auth_token = @access_token
  erb :success
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/callback'
  uri.query = nil
  uri.to_s
end
