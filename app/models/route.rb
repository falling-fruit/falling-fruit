class Route < ActiveRecord::Base
  belongs_to :user
  has_many :locations, :through => :locations_route
  has_many :locations_routes, :order => "locations_routes.position ASC"
  attr_accessible :name, :type
end
