class Change < ActiveRecord::Base
  attr_accessible :description, :remote_ip, :updated_at, :created_at, :location, :location_id, :user, :user_id
  validates :description, :presence => true
  belongs_to :location
  belongs_to :user
end
