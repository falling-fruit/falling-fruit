class ApiKey < ActiveRecord::Base
  attr_accessible :api_key,:api_type,:name,:version

  before_validation { |record|
    record.api_key = ApiKey.random_key if record.api_key.nil?
  }

  def can?(endpoint)
    return true if self.api_type == "internal"
    return true if self.api_type == "muni" and ["api/locations/cluster","api/locations/nearby",
                                                "api/locations/markers","api/locations/marker","api/locations/show",
                                                "api/locations/cluster_types","api/locations/types"].include? endpoint
    return false
  end

  # class methods

  def self.random_key
    (0...8).map { (65 + rand(26)).chr }.join
  end

  def self.find_it(check)
    ApiKey.find_by_api_key(check.to_s)
  end
end