require 'pony'
require 'date'
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
task :email_orders, [:to, :from, :category_id, :cutoff_day] do |t, args|
  unless Date.today.strftime("%A").downcase == args[:cutoff_day].downcase
    abort("Skipping task until #{args[:cutoff_day]}")
  end

  puts "Emailing orders to #{args[:to]} from #{args[:from]}"

  category_id = args[:category_id].to_i
  created_since = DateTime.now - 7
  # Endpoint to get a single category is not available
  category_name = Tidyhq.client.categories.all.find {|c| c.id == category_id}.name

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
    subject: "#{category_name} - Order sheet #{created_since.strftime("%Y-%m-%d")}",
    body: "#{category_name} orders since #{created_since.strftime("%B %d, %Y %I:%M %p")}",
    attachments: {
      "orders-#{category_id}-#{created_since}.csv" => orders_csv(category_id, created_since.to_s)
    }
  })

  puts "done."
end
