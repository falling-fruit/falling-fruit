class Location < ActiveRecord::Base
  belongs_to :region
  belongs_to :type
  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, :title
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "lat", :lng => "lng", :address => "address"
  after_validation :geocode
end
