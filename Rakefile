require 'pony'

if ENV['RACK_ENV'] == 'development'
  require 'dotenv'
  Dotenv.load
end

desc "This task is called by the Heroku scheduler add-on"
task :email_orders, [:to, :from] do |t, args|
  puts "Emailing orders to #{args[:to]} from #{args[:from]}"
  Pony.mail({
    to: args[:to],
    from: args[:from],
    subject: "Orders #{Time.now}",
    via: :smtp,
    via_options: {
      address: 'smtp.sendgrid.net',
      port: 25,
      authentication: :plain,
      user_name: ENV['SENDGRID_USERNAME'],
      password: ENV['SENDGRID_PASSWORD']
      domain: ENV['DOMAIN']
    }
  })
  puts "done."
end
