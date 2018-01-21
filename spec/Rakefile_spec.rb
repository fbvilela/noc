require 'spec_helper'
require 'webmock/rspec'
require 'rake'
require 'dotenv'
Dotenv.load

def tidyhq_request(path, params={})
  query = URI.encode_www_form({ access_token: ENV['TIDYHQ_ACCESS_CODE'] }.merge(params))
  "https://api.tidyhq.com/v1/#{path}?#{query}"
end

def stub_tidyhq_request(path, response, method: :get, params: {})
  stub_request(method, tidyhq_request(path, params)).
    to_return(body: response.to_json)
end

describe "Rakefile" do
  before :all do
    load File.expand_path("../../Rakefile", __FILE__)
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  describe 'email_orders' do
    let(:to) { "orders@newportorganiccollective.com" }
    let(:from) { "contact@newportorganiccollective.com" }
    let(:category_id) { 200303 }
    let(:cutoff_day) { "Monday" }

    after do
      Rake::Task["email_orders"].reenable
    end

    context 'outside of cutoff_day' do
      before do
        allow(Date).to receive(:today).and_return Date.new(2018,01,21)
      end

      it 'skips task until the cut-off' do
        expect {
          Rake::Task["email_orders"].invoke(to, from, category_id, cutoff_day)
        }.to raise_error(SystemExit).and output("Skipping task until Monday\n").to_stderr
      end
    end

    context 'on cut-off day' do
      let(:cutoff_date) { DateTime.new(2018,01,22) }
      let(:created_since) { cutoff_date - 7 }

      let(:category) {
        {
          id: category_id,
          name: "Bread from Candied Bakery",
        }
      }

      let(:contact1) {
        {
          id: 1841527,
          first_name: "Daniel",
          last_name: "Breves",
          phone_number: "0123 456 789",
          email_address: "daniel@breves.com"
        }
      }

      let(:contact2) {
        {
          id: 1835253,
          first_name: "Fabio",
          last_name: "Vilela",
          phone_number: "0987 654 321",
          email_address: "fabio@vilela.com"
        }
      }

      let(:products) {
        [
          {
            id: "3bb636a132bd",
            name: "Organic Mixed Produce Box",
            sell_price: 30.60,
            sell_category_id: 200304
          },
          {
            id: "f8550a0ad718",
            name: "Country White Sourdough",
            sell_price: 4.59,
            sell_category_id: category_id
          },
          {
            id: "a63efc4da576",
            name: "Olive Sourdough",
            sell_price: 5.05,
            sell_category_id: category_id
          }
        ]
      }

      let(:orders) {
        [
          {
            id: "d200e9330adb",
            number: 25210351705,
            contact_id: contact1[:id],
            created_at: cutoff_date - 3,
            products: [
              {
                product_id: products[0][:id],
                quantity: 1
              },
              {
                product_id: products[1][:id],
                quantity: 2
              }
            ]
          },
          {
            id: "cd932840ce42",
            number: 40102376573,
            contact_id: contact2[:id],
            created_at: cutoff_date - 5,
            products: [
              {
                product_id: products[2][:id],
                quantity: 1
              }
            ]
          },
        ]
      }

      before do
        allow(Pony).to receive(:mail)
        allow(Date).to receive(:today).and_return cutoff_date
        allow(DateTime).to receive(:now).and_return cutoff_date

        stub_tidyhq_request("categories", [category])
        stub_tidyhq_request("shop/products", products)
        stub_tidyhq_request("shop/orders", orders, params: { created_since: created_since })
        stub_tidyhq_request("contacts", [contact1, contact2])
      end

      it 'sends an email with order CSVs attached' do
        expect {
          Rake::Task["email_orders"].invoke(to, from, category_id, cutoff_day)
        }.to output("Emailing orders to #{to} from #{from}\ndone.\n").to_stdout

        order_line_1 = [
          orders[0][:number],
          orders[0][:created_at].strftime("%Y-%m-%d %I:%M %p"),
          "#{contact1[:first_name]} #{contact1[:last_name]}",
          contact1[:phone_number],
          contact1[:email_address],
          products[1][:name],
          orders[0][:products][1][:quantity],
          products[1][:sell_price]
        ]

        order_line_2 = [
          orders[1][:number],
          orders[1][:created_at].strftime("%Y-%m-%d %I:%M %p"),
          "#{contact2[:first_name]} #{contact2[:last_name]}",
          contact2[:phone_number],
          contact2[:email_address],
          products[2][:name],
          orders[1][:products][0][:quantity],
          products[2][:sell_price]
        ]

        summary_line_1 = [
          products[1][:name],
          orders[0][:products][1][:quantity],
          products[1][:sell_price],
          (orders[0][:products][1][:quantity] * products[1][:sell_price])
        ]

        summary_line_2 = [
          products[2][:name],
          orders[1][:products][0][:quantity],
          products[2][:sell_price],
          (orders[1][:products][0][:quantity] * products[2][:sell_price])
        ]

        total_qty = summary_line_1[1] + summary_line_2[1]
        total_cost = summary_line_1[3] + summary_line_2[3]

        expect(Pony).to have_received(:mail).with(
          {
            to: to,
            from: from,
            subject: "#{category[:name]} - Orders since #{created_since.strftime("%Y-%m-%d")}",
            body: "#{category[:name]} - Orders since #{created_since.strftime("%B %d, %Y %I:%M %p")}",
            attachments: {
              "orders-#{category_id}-#{created_since}.csv" => "Order Number,Placed On,Name,Phone,Email,Item,Qty,Price\n#{order_line_1.join(',')}\n#{order_line_2.join(',')}\n",
              "summary-#{category_id}-#{created_since}.csv"=> "Product,Qty,Unit Price,Total cost\n#{summary_line_1.join(',')}\n#{summary_line_2.join(',')}\nTotal,#{total_qty},\"\",#{total_cost}\n"
            }
          }
        )
      end
    end
  end

  describe 'delete_expired' do
    let(:group_id) { 52355 }
    let(:membership_contact_id) { 1841527 }

    let(:membership) {
      {
        id: 164086,
        contact_id: membership_contact_id,
        membership_level_id: 8137,
        state: "activated"
      }
    }

    let(:group) {
      {
        id: group_id,
        name: "Active Members"
      }
    }

    let(:contact_with_active_membership) {
      {
        id: membership_contact_id,
        first_name: "Daniel",
        last_name: "Breves"
      }
    }

    let(:contact_part_of_active_membership) {
      {
        id: 1834116,
        first_name: "Manuella",
        last_name: "Breves Ribeiro"
      }
    }

    let(:contact_without_active_membership) {
      {
        id: 1835253,
        first_name: "Fabio",
        last_name: "Vilela"
      }
    }

    before do
      stub_tidyhq_request("memberships", [membership], params: { active: true })
      stub_tidyhq_request("groups/#{group_id}", group)
      stub_tidyhq_request("groups/#{group_id}/contacts", [
        contact_with_active_membership,
        contact_part_of_active_membership,
        contact_without_active_membership
      ])
      stub_tidyhq_request("contacts/#{contact_part_of_active_membership[:id]}", contact_part_of_active_membership)
      stub_tidyhq_request("contacts/#{contact_part_of_active_membership[:id]}/memberships", [membership], params: { active: true })
      stub_tidyhq_request("contacts/#{contact_without_active_membership[:id]}", contact_without_active_membership)
      stub_tidyhq_request("contacts/#{contact_without_active_membership[:id]}/memberships", [], params: { active: true })
      stub_tidyhq_request("groups/#{group_id}/contacts/#{contact_without_active_membership[:id]}", "", method: :delete)
    end

    after do
      Rake::Task["delete_expired"].reenable
    end

    it 'deletes members without active memberships from the specified group' do
      expect {
        Rake::Task["delete_expired"].invoke(group_id)
      }.to output("Deleting Fabio Vilela from group \n").to_stdout

      assert_not_requested :delete, tidyhq_request("groups/#{group_id}/contacts/#{contact_part_of_active_membership[:id]}")
      assert_requested :delete, tidyhq_request("groups/#{group_id}/contacts/#{contact_without_active_membership[:id]}")
    end
  end
end
