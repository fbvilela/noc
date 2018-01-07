require 'csv'

class CsvGenerator
  def initialize(tidyhq)
    @tidyhq = tidyhq
  end

  def generate(category_id, created_since)
    products = @tidyhq.products.all
    orders = @tidyhq.orders.all(created_since: created_since)
    contacts = @tidyhq.contacts.all

    CSV.generate do |csv|
      csv << ["Order Number", "Placed On", "Name", "Phone", "Email", "Items"]
      orders.each do |order|
        product_orders = []
        order.products.each do |product_order|
          product = products.find {|prod| prod.id === product_order.product_id }
          if (product.sell_category_id === category_id)
            product_orders << "#{product.name} (#{product_order.quantity})"
          end
        end
        unless product_orders.empty?
          contact = contacts.find {|c| c.id === order.contact_id }
          csv << [
            order.number,
            order.created_at.strftime("%Y-%m-%d %I:%M %p"),
            "#{contact.first_name} #{contact.last_name}",
            contact.phone_number,
            contact.email_address,
            product_orders.join('; ')
          ]
        end
      end
    end
  end
end
