require 'pony'
require 'date'
require_relative 'lib/tidyhq'
require_relative 'lib/csv_generator'

ONE_WEEK = 7

case ENV['RACK_ENV']
when 'production'
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
when 'test'
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)
  task :default => :spec
when 'development'
  require 'dotenv'
  Dotenv.load
end

def orders_csv_data(category_id, created_since)
  CsvGenerator.new(Tidyhq.client).generate(category_id, created_since)
end

desc "This task is called by the Heroku scheduler add-on to email orders"
task :email_orders, [:to, :from, :category_id, :cutoff_day] do |t, args|
  unless Date.today.strftime("%A").downcase == args[:cutoff_day].downcase
    abort("Skipping task until #{args[:cutoff_day]}")
  end

  puts "Emailing orders to #{args[:to]} from #{args[:from]}"

  category_id = args[:category_id].to_i
  created_since = DateTime.now - ONE_WEEK
  # Endpoint to get a single category is not available
  category_name = Tidyhq.client.categories.all.find {|c| c.id == category_id}.name

  csv_data = orders_csv_data(category_id, created_since.to_s)

  Pony.mail({
    to: args[:to],
    from: args[:from],
    subject: "#{category_name} - Orders since #{created_since.strftime("%Y-%m-%d")}",
    body: "#{category_name} - Orders since #{created_since.strftime("%B %d, %Y %I:%M %p")}",
    attachments: {
      "orders-#{category_id}-#{created_since}.csv" => csv_data[:list],
      "summary-#{category_id}-#{created_since}.csv" => csv_data[:summary]
    }
  })

  puts "done."
end

desc "This task is called by the Heroku scheduler add-on to delete expired memberships from a group"
task :delete_expired, [:group_id] do |t, args|
  group_id = args[:group_id].to_i
  active_memberships = Tidyhq.client.memberships
                                    .all(active: true)
                                    .map(&:contact_id)

  group = Tidyhq.client.groups.get(group_id)
  group_contacts = group.contacts.all.map(&:id)
  (group_contacts - active_memberships).each do |contact_id|
    contact = Tidyhq.client.contacts.get(contact_id)
    # Make sure contact isn't part of any active membership
    if contact.memberships.all(active: true).empty?
      puts "Deleting #{contact.first_name} #{contact.last_name} from group #{group.label}"
      group.contacts.delete(contact_id)
    end
  end
end
