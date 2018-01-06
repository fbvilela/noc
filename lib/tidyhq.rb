require 'tidyhqrb'

class Tidyhq
  def self.client
    Tidyhqrb::Client.auth_token = ENV['TIDYHQ_ACCESS_CODE'] unless ENV['TIDYHQ_ACCESS_CODE'].nil?
    @@client ||= Tidyhqrb::Client.new
  end
end
