class Route < ActiveRecord::Base
  belongs_to :user
  has_many :locations, :through => :locations_route
  has_many :locations_routes, :order => "locations_routes.position ASC"
  attr_accessible :name, :transport_type, :is_public, :access_key

  set_inheritance_column 'does_not_have_one'
  normalize_attributes *character_column_symbols

  TransportTypes = ["Walking","Bicycling","Driving"]
end
