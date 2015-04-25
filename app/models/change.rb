class Change < ActiveRecord::Base
  attr_accessible :description, :remote_ip, :updated_at, :created_at, :location, :location_id, :user, :user_id
  belongs_to :location
  belongs_to :user
  belongs_to :observation
  
  normalize_attributes *character_column_symbols
  validates :description, :presence => true
  
  ChangeTypes = ["edited","added","visited","grafted"]
end
