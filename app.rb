require 'sinatra'
require 'oauth2'
require 'json'
require_relative 'lib/tidyhq'
require_relative 'lib/csv_generator'

CLIENT = ENV['TIDYHQ_CLIENT']
SECRET = ENV['TIDYHQ_SECRET']
TOKEN = ENV['TOKEN']

class App < Sinatra::Base
  enable :sessions

  before do
    session[:token] = params[:token] if params[:token]
    halt 401, "Not authorized\n" if TOKEN.nil? || TOKEN.empty? || session[:token] != TOKEN
  end

  get '/logout' do
    session.clear
    redirect '/'
  end

  get '/' do
    if ENV['TIDYHQ_ACCESS_CODE'].nil? || ENV['TIDYHQ_ACCESS_CODE'].empty?
      erb :index
    else
      erb :success
    end
  end

  get "/auth" do
    redirect oauth_client.auth_code.authorize_url(:redirect_uri => redirect_uri)
  end

  get '/callback' do
    access_token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
    @access_token = access_token.token
    ENV['TIDYHQ_ACCESS_CODE'] = access_token.token
    erb :success
  end

  get '/groups/:id/contacts' do
    @contacts = tidyhq.groups.get(params['id'].to_i).contacts.all
    erb :contacts
  end

  private

  def oauth_client
    client ||= OAuth2::Client.new(CLIENT, SECRET, {
      :site => 'https://accounts.tidyhq.com',
      :authorize_url => "/oauth/authorize",
      :token_url => "/oauth/token"
    })
  end

  def tidyhq
    Tidyhq.client
  end

  def redirect_uri
    uri = URI.parse(request.url)
    uri.path = '/callback'
    uri.query = nil
    uri.to_s
  end
end
