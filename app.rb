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
    halt 401, "Not authorized\n" if TOKEN.nil? || session[:token] != TOKEN
  end

  get '/logout' do
    session.clear
    redirect '/'
  end

  get '/' do
    redirect '/success' unless ENV['TIDYHQ_ACCESS_CODE'].nil?
    erb :index
  end

  get "/auth" do
    redirect oauth_client.auth_code.authorize_url(:redirect_uri => redirect_uri)
  end

  get '/callback' do
    access_token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
    ENV['TIDYHQ_ACCESS_CODE'] = access_token.token
    redirect '/success'
  end

  get '/success' do
    erb :success
  end

  get '/contacts.json' do
    content_type :json
    tidyhq.contacts.all.to_json
  end

  get '/orders.json' do
    content_type :json
    tidyhq.orders.all.to_json
  end

  get '/products.json' do
    content_type :json
    tidyhq.products.all.to_json
  end

  get '/products/:category_id.json' do
    content_type :json
    tidyhq.products.all.select do |product|
      product.sell_category_id === params['category_id'].to_i
    end.to_json
  end

  get '/products/:category_id/orders.json' do
    content_type :json
    products = tidyhq.products.all
    orders = tidyhq.orders.all(created_since: params['created_since'])
    orders.select do |order|
      order.products.any? do |product_order|
        product = products.find {|prod| prod.id === product_order.product_id }
        product.sell_category_id === params['category_id'].to_i
      end
    end.to_json
  end

  get '/products/:category_id/orders.csv' do
    content_type 'application/csv'
    attachment "orders-#{params['category_id']}-#{params['created_since']}.csv"

    CsvGenerator.new(tidyhq).generate(params['category_id'].to_i, params['created_since'])
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
