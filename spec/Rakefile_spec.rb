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

  before :all do
    load File.expand_path("../../Rakefile", __FILE__)
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  describe 'delete_expired' do
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

    it 'deletes members without active memberships from the specified group' do
      expect {
        Rake::Task["delete_expired"].invoke(group_id)
      }.to output("Deleting Fabio Vilela from group \n").to_stdout

      assert_not_requested :delete, tidyhq_request("groups/#{group_id}/contacts/#{contact_part_of_active_membership[:id]}")
      assert_requested :delete, tidyhq_request("groups/#{group_id}/contacts/#{contact_without_active_membership[:id]}")
    end
  end
end
