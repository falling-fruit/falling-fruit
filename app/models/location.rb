class Location < ActiveRecord::Base
  belongs_to :region
  belongs_to :type

  validates :title, :author, :presence => true
  validates :lat, :lng, :numericality => true, :allow_nil => true
  validates :region_id, :type_id, :numericality => { :only_integer => true }, :allow_nil => true

  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, :title, :no_season, :inaccessible, :region_id, :type_id
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "lat", :lng => "lng", :address => "address"
  after_validation :geocode

  public 

  Months = ["January","February","March","April","May","June","July","August","September","October","November","December"]

  def gmaps4rails_title
    self.title
  end

  def gmaps4rails_infowindow
    ret = "<strong>#{self.title}</strong><br>"
    ret += "Added by #{self.author}<br>"
    unless self.type.nil?
      ret += "Type: #{self.type.name}<br>"
    end
    unless self.no_season or self.season_start.nil? or self.season_stop.nil?
      ret += "Fruiting from #{Months[season_start]} to #{Months[season_stop]}<br>"
    end
    ret += "<a href=\"/locations/#{self.id}/edit\">Edit</a><br>"
    ret
  end

  def gmaps4rails_marker_picture
    {
      "picture" => (self.type.nil? or self.type.marker_file_name.nil?) ? "http://maps.gstatic.com/intl/en_ALL/mapfiles/dd-end.png" : self.type.marker.url,
      "width" => 30,
      "height" => 30,
      "marker_anchor" => [5, 10],
      #"shadow_picture" => "/images/morgan.png" ,
      #"shadow_width" => "110",
      #"shadow_height" => "110",
      #"shadow_anchor" => [5, 10],
    }
  end
end
