require 'sinatra'
require 'oauth2'
require 'json'
require 'tidyhqrb'


enable :sessions

CLIENT = '58de4c6c9173afea592bbd20b1fab08b94784e55c86b677572d079b0664b3bad'
SECRET = '924b7709ad942c6b1e7fdeb039e79f7e67fe0fe45cb9f8927594551675beadfb'

def client
  client ||= OAuth2::Client.new(CLIENT, SECRET, {
                :site => 'https://accounts.tidyhq.com',
                :authorize_url => "/oauth/authorize",
                :token_url => "/oauth/token"
              })
end

get '/' do
  erb :index
end

get '/test' do
  @contacts = Tidyhq::Client.new.contacts.all
  erb :test
end

get "/auth" do
  redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri)
end

get '/callback' do
  access_token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
  session[:access_token] = access_token.token
  @message = "Successfully authenticated with the server"
  @access_token = session[:access_token]
  Tidyhq::Client.auth_token = @access_token
  erb :success
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/callback'
  uri.query = nil
  uri.to_s
end
