class Location < ActiveRecord::Base
  belongs_to :region
  belongs_to :type
  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, :title, :no_season, :inaccessible
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "lat", :lng => "lng", :address => "address"
  after_validation :geocode

  public 

  Months = ["January","February","March","April","May","June","July","August","September","October","November","December"]

  def gmaps4rails_infowindow
    ret = "<strong>" + self.title + "</strong><br>"
    ret += "Added by #{self.author}<br>"
    unless self.type.nil?
      ret += "Type: #{self.type.name}<br>"
    end
    unless self.no_season
      ret += "Fruiting from #{Months[season_start]} to #{Months[season_stop]}<br>"
    end
  end
end
