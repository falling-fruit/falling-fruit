class ApiKey < ActiveRecord::Base
  attr_accessible :key,:name,:version

  before_validation { |record|
    record.api_key = ApiKey.random_key if record.api_key.nil?
  }

  def self.random_key
    (0...8).map { (65 + rand(26)).chr }.join
  end
end