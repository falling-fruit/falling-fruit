class Location < ActiveRecord::Base
  include ActionView::Helpers::TextHelper # for word_wrap

  has_many :locations_types
  has_many :types, :through => :locations_types
  belongs_to :import

  #validates :author, :presence => true
  validates :lat, :lng, :numericality => true, :allow_nil => true
  validates :quality_rating, :yield_rating, :access, :numericality => { :only_integer => true }, :allow_nil => true

  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, 
                  :no_season, :quality_rating, :yield_rating, :unverified, :access, :locations_types, :import_id, :cultivar, :photo_url
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  acts_as_gmappable :process_geocoding => false, :lat => "lat", :lng => "lng", :address => "address"
  after_validation :geocode
  # manually update postgis location object
  after_validation { |record| record.location = "POINT(#{record.lng} #{record.lat})" unless [record.lng,record.lat].any? { |e| e.nil? } }

  public 

  Months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
  Ratings = ["Crummy","Not Great","Decent","Solid","Epic"]
  AccessModes = ["I own this source",
                 "I have permission from the owner to add this source",
                 "Source is on public land",
                 "Source is on private property but overhangs public land",
                 "Source is on private property (ask before you pick)"]

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
    photo_url
  end

  def title
    lt = self.locations_types
    if lt.length == 2
      "#{lt[0].name} and #{lt[1].name}"
    elsif lt.length > 2
      "#{lt[0].name} & Others"
    else
      lt[0].name
    end
  end

  def scsv_types
    self.locations_types.collect{ |lt| lt.type.nil? ? nil : lt.type.name }.compact.join(";")
  end

  def scsv_type_others
    self.locations_types.collect{ |lt| lt.type_other }.compact.join(";")
  end
  
  def self.csv_header
    ["Type","Type Other","Description","Lat","Lng","Address","Season Start","Season Stop",
     "No Season","Access","Unverified","Yield Rating","Quality Rating","Author","Photo URL"]
  end

  def self.build_from_csv(row)
    type,type_other,desc,lat,lng,address,season_start,season_stop,no_season,access,unverified,yield_rating,quality_rating,author,photo_url = row
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
    loc.photo_url = photo_url
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

end
