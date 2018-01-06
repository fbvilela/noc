require 'sinatra'
require 'oauth2'
require 'json'
require 'tidyhqrb'
require 'csv'

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

get '/products/:product_id.json' do
  content_type :json
  tidyhq.products.get(params['product_id']).to_json
end

get '/products/:product_id/orders.json' do
  content_type :json

  orders = tidyhq.orders.all(created_since: params['created_since'])
  orders.select do |order|
    order.products.any? do |product|
      product.product_id === params['product_id']
    end
  end.to_json
end

get '/products/:product_id/orders.csv' do
  content_type 'application/csv'
  attachment "orders-#{params['product_id']}-#{params['created_since']}.csv"

  product_name = tidyhq.products.get(params['product_id']).name
  orders = tidyhq.orders.all(created_since: params['created_since'])
  contacts = tidyhq.contacts.all

  CSV.generate do |csv|
    csv << ["Order Number", "Placed On", "Name", "Phone", "Email", "Items"]
    orders.each do |order|
      order.products.each do |product|
        if (product.product_id === params['product_id'])
          contact = contacts.find {|c| c.id === order.contact_id }
          csv << [
            order.number,
            order.created_at,
            "#{contact.first_name} #{contact.last_name}",
            contact.phone_number,
            contact.email_address,
            "#{product_name} (#{product.quantity})"
          ]
        end
      end
    end
  end
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
