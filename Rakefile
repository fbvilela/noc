require 'pony'
require_relative 'lib/tidyhq'
require_relative 'lib/csv_generator'

if ENV['RACK_ENV'] == 'development'
  require 'dotenv'
  Dotenv.load
end

def orders_csv(category_id, created_since)
  CsvGenerator.new(Tidyhq.client).generate(category_id, created_since)
end

desc "This task is called by the Heroku scheduler add-on"
task :email_orders, [:to, :from, :category_id, :created_since] do |t, args|
  puts "Emailing orders to #{args[:to]} from #{args[:from]}"

  category_id = args[:category_id].to_i
  created_since = args[:created_since]

  if ENV['RACK_ENV'] == 'production'
    Pony.options ={
      via: :smtp,
      via_options: {
        address: 'smtp.sendgrid.net',
        port: 25,
        authentication: :plain,
        user_name: ENV['SENDGRID_API_USER'],
        password: ENV['SENDGRID_API_KEY'],
        domain: ENV['DOMAIN']
      }
    }
  end

  Pony.mail({
    to: args[:to],
    from: args[:from],
    subject: "Orders #{Time.now}",
    attachments: {
      "orders-#{category_id}-#{created_since}.csv" => orders_csv(category_id, created_since)
    }
  })

  puts "done."
end
