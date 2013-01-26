class Region < ActiveRecord::Base
  attr_accessible :center_address, :center_lat, :center_lng, :name
  validates :name, :center_address, :presence => true
  validates :center_lat, :center_lng, :numericality => true, :allow_nil => true
  geocoded_by :center_address, :latitude => :center_lat, :longitude => :center_lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "center_lat", :lng => "center_lng", :address => "center_address"
  after_validation :geocode
end
