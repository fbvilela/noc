require 'csv'

class CsvGenerator
  def initialize(tidyhq)
    @tidyhq = tidyhq
  end

  def generate(category_id, created_since)
    products = @tidyhq.products.all.select {|product| product.sell_category_id === category_id }
    orders = @tidyhq.orders.all(created_since: created_since)
    contacts = @tidyhq.contacts.all

    orders_data = format_orders_data(products, orders, contacts)
    csv_data = {}

    csv_data[:list] = CSV.generate do |csv|
      csv << ["Order Number", "Placed On", "Name", "Phone", "Email", "Item", "Qty", "Price"]
      orders_data[:list].each {|order| csv << order }
    end

    csv_data[:summary] = CSV.generate do |csv|
      total_qty = 0
      total_price = 0.0
      csv << ["Product", "Qty", "Unit Price", "Total cost"]
      orders_data[:summary].each do |key, value|
        total_qty += value[:qty]
        subtotal_price = value[:qty] * value[:price]
        total_price += subtotal_price
        csv << [key, value[:qty], value[:price], subtotal_price]
      end
      csv << ["Total", total_qty, "", total_price]
    end

    csv_data
  end

  private

  def products_for_category(category_id)
    @tidyhq.products.all.select do |product|
      product.sell_category_id === category_id
    end
  end

  def orders_created_since(created_since)
    @tidyhq.orders.all(created_since: created_since)
  end

  def format_orders_data(products, orders, contacts)
    list = []
    summary = products.reduce({}) do |memo, product|
      memo[product.name] = { qty: 0, price: product.sell_price }
      memo
    end

    orders.each do |order|
      contact = contacts.find {|c| c.id === order.contact_id }
      order.products.each do |product_order|
        product = products.find {|prod| prod.id === product_order.product_id }
        unless (product.nil?)
          summary[product.name][:qty] += product_order.quantity
          list << [
            order.number,
            order.created_at.strftime("%Y-%m-%d %I:%M %p"),
            "#{contact.first_name} #{contact.last_name}",
            contact.phone_number,
            contact.email_address,
            product.name,
            product_order.quantity,
            product.sell_price
          ]
        end
      end
    end

    { list: list, summary: summary }
  end
end
