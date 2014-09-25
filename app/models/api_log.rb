class ApiLog < ActiveRecord::Base
  attr_accessible :n,:endpoint,:request_method,:params,:ip_address,:api_key
end
