class Location < ActiveRecord::Base
  include ActionView::Helpers::TextHelper # for word_wrap

  has_many :locations_types
  has_many :types, :through => :locations_types
  belongs_to :import

  validates :author, :presence => true
  validates :lat, :lng, :numericality => true, :allow_nil => true
  validates :quality_rating, :yield_rating, :access, :numericality => { :only_integer => true }, :allow_nil => true

  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, 
                  :no_season, :quality_rating, :yield_rating, :unverified, :access, :locations_types, :import_id, :cultivar
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "lat", :lng => "lng", :address => "address"
  after_validation :geocode

  public 

  Months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
  Ratings = ["Crummy","Not Great","Decent","Solid","Epic"]
  AccessModes = ["I own this source and want to include it in the public database",
                 "The owner of this source gave me permission to include it in the public database",
                 "This source is on public property",
                 "This source is on private property but an abundance of fruit is on the ground or overhangs public walkway",
                 "This source is on private property (ask before you pick)"]

  # csv support
  comma do
    scsv_types
    scsv_type_others
    description
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

  def scsv_types
    self.locations_types.collect{ |lt| lt.type.nil? ? nil : lt.type.name }.compact.join(";")
  end

  def scsv_type_others
    self.locations_types.collect{ |lt| lt.type_other }.compact.join(";")
  end
  
  def self.csv_header
    ["Type","Type Other","Description","Lat","Lng","Address","Season Start","Season Stop",
     "No Season","Access","Unverified","Yield Rating","Quality Rating","Author"]
  end

  def self.build_from_csv(row)
    type,type_other,desc,lat,lng,address,season_start,season_stop,no_season,access,unverified,yield_rating,quality_rating,author = row
    loc = Location.new
    unless type.nil? or type.strip.length == 0
      type.split(/[;,:]/).each{ |t|
        safer_type = t.tr('^A-Za-z- ','').capitalize
        types = Type.where("name='#{safer_type}'")
        if types.count == 0
          nt = Type.new
          nt.name = safer_type
          nt.save

          lt = LocationsType.new
          lt.type = nt
          lt.save

          loc.locations_types.push lt
        else
          loc.types.push types.shift
        end
      }
    end
    type_other.split(/[;,:]/).each{ |to|
      lt = LocationsType.new
      lt.type_other = to
      lt.save          
      loc.locations_types.push lt
    } unless type_other.nil? or type_other.strip.length == 0
    unless lat.nil? or lng.nil? or lat.strip.length == 0 or lng.strip.length == 0
      loc.lat = lat.to_f
      loc.lng = lng.to_f
    end
    loc.description = desc
    loc.address = address
    loc.season_start = season_start.to_i unless season_start.nil? or season_start.strip == ""
    loc.season_stop = season_stop.to_i unless season_stop.nil? or season_stop.strip == ""
    no_season = no_season.nil? ? "" : no_season.strip.downcase.tr('^a-z','')
    unverified = unverified.nil? ? "" : unverified.strip.downcase.tr('^a-z','')
    loc.no_season = true if no_season == 't' or no_season == "true" or no_season == "x"
    loc.unverified = true if unverified == 't'or unverified == "true" or unverified == "x"
    loc.yield_rating = yield_rating.to_i unless yield_rating.nil? or yield_rating.strip == ""
    loc.quality_rating = quality_rating.to_i unless quality_rating.nil? or quality_rating.strip == ""
    loc.author = author
    return loc 
  end

  def title
    self.locations_types.collect{ |lt| lt.type.nil? ? lt.type_other : lt.type.name }.join(",")
  end

  def gmaps4rails_title
    self.title
  end

  def gmaps4rails_infowindow
    ret = "<div style=\"background: #003366;font-weight:bold;color:white;padding:0.2em;\">#{self.title}</div><br>"
    ret += "#{word_wrap(self.description,:line_width => 30).gsub("\n","<br>")}<br><br>" unless self.description.nil?
    ret += "Fruiting from #{Months[season_start]} to #{Months[season_stop]}<br>" unless self.no_season or 
      self.season_start.nil? or self.season_stop.nil? 
    usda_links = self.locations_types.collect{ |lt| 
      lt.type.nil? or lt.type.usda_profile_url.nil? ? nil : "<a target=\"_blank\" href=\"#{lt.type.usda_profile_url}\">#{lt.type.name}</a>" 
    }.compact
    ret += "USDA Profiles: " + usda_links.join(" | ") + "<br>" unless usda_links.length == 0
    wp_links = self.locations_types.collect{ |lt| lt.type.nil? ? nil : "<a target=\"_blank\" 
               href=\"#{lt.type.wikipedia_url}\">#{lt.type.name}</a>" }.compact
    ret += "Wikipedia: " + wp_links.join(" | ") + "<br>" unless wp_links.length == 0
    ret += "<span style=\"text-decoration: italic;color: grey;\">Added by #{self.author}</span><br>"
    ret += "<div style=\"float: right;\"><a href=\"/locations/#{self.id}/edit\">Edit</a>"
    ret += " | <a data-confirm=\"Are you sure?\" data-method=\"delete\" rel=\"nofollow\" 
                  href=\"/locations/#{self.id}\">Delete</a></div>" unless Admin.current_admin.nil?
    ret += "</div>"
    ret
  end

  def gmaps4rails_marker_picture
    {
      #"picture" => "https://maps.gstatic.com/intl/en_us/mapfiles/markers2/measle_blue.png"
      "picture" => self.unverified ? "/smdot_grey.png" : "/smdot_red.png",
      "width" => 7,
      "height" => 7,
      #"marker_anchor" => [5, 10],
      #"shadow_picture" => "/images/morgan.png" ,
      #"shadow_width" => "110",
      #"shadow_height" => "110",
      #"shadow_anchor" => [5, 10],
    }
  end
end
