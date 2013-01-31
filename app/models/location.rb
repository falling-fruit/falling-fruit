class Location < ActiveRecord::Base
  belongs_to :region
  belongs_to :type

  validates :author, :presence => true
  validates :lat, :lng, :numericality => true, :allow_nil => true
  validates :region_id, :type_id, :quality_rating, :yield_rating, :access, :numericality => { :only_integer => true }, :allow_nil => true

  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, 
                  :no_season, :region_id, :type_id, :quality_rating, :yield_rating, :type_other, :unverified, :access
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "lat", :lng => "lng", :address => "address"
  after_validation :geocode

  public 

  Months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
  Ratings = ["Crummy","Not Great","Decent","Solid","Epic"]
  AccessModes = ["I own this source and want to include it in the public database",
            "The owner of this source gave me permission to include it in the public database",
            "This source is on public property",
            "This source is on private property but an abundance of fruit is on the ground or overhangs public walkway"]

  # csv support
  comma do
    title
    type_other
    lat
    lng
    address
    season_start
    season_stop
    no_season
    access
    unverified
    yield_rating
    quality_rating
    author
  end
  
  def self.csv_header
    ["Type","Type Other","Lat","Lng","Address","Season Start","Season Stop","No Season","Access","Unverified","Yield Rating","Quality Rating","Author"]
  end

  def self.build_from_csv(row)
    type,type_other,lat,lng,address,season_start,season_stop,no_season,access,unverified,yield_rating,quality_rating,author = row
    loc = Location.new
    unless type.nil? or type.strip.length == 0
      safer_type = type.tr('^A-Za-z- ','')
      types = Type.where("name='#{safer_type}'")
      if types.count == 0
        type_other = type
        type = nil
      else
        type_other = nil
        type = types.shift
      end
      loc.type = type
    end
    loc.type_other = type_other
    unless lat.nil? or lng.nil? or lat.strip.length == 0 or lng.strip.length == 0
      loc.lat = lat.to_f
      loc.lng = lng.to_f
    end
    loc.address = address
    loc.season_start = season_start.to_i unless season_start.nil? or season_start.strip == ""
    loc.season_stop = season_stop.to_i unless season_stop.nil? or season_stop.strip == ""
    no_season = no_season.strip.downcase.tr('^a-z','')
    unverified = unverified.strip.downcase.tr('^a-z','')
    loc.no_season = true if no_season == 't' or no_season == "true" or no_season == "x"
    loc.unverified = true if unverified == 't'or unverified == "true" or unverified == "x"
    loc.yield_rating = yield_rating.to_i unless yield_rating.nil? or yield_rating.strip == ""
    loc.quality_rating = quality_rating.to_i unless quality_rating.nil? or quality_rating.strip == ""
    loc.author = author
    return loc 
  end

  def title
    self.type.nil? ? self.type_other : self.type.name
  end

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
      #"picture" => "https://maps.gstatic.com/intl/en_us/mapfiles/markers2/measle_blue.png"
      #"width" => 20,
      #"height" => 20,
      #"marker_anchor" => [5, 10],
      #"shadow_picture" => "/images/morgan.png" ,
      #"shadow_width" => "110",
      #"shadow_height" => "110",
      #"shadow_anchor" => [5, 10],
    }
  end
end
