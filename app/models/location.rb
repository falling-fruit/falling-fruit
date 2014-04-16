class Location < ActiveRecord::Base
  include ActionView::Helpers::TextHelper # for word_wrap

  has_many :locations_types, :order => 'locations_types.position ASC'
  has_many :types, :through => :locations_types, :order => 'locations_types.position ASC'
  has_many :observations
  has_many :changes, :dependent => :delete_all
  belongs_to :import
  belongs_to :user

  validates_associated :locations_types
  validates :locations_types, :presence => true
  validates :lat, numericality: {greater_than_or_equal_to: -85.0, less_than_or_equal_to: 85.0, allow_nil: false}
  validates :lat, numericality: {greater_than_or_equal_to: -180.0, less_than_or_equal_to: 180.0, allow_nil: false}
  validates :access, :numericality => { :only_integer => true }, :allow_nil => true
	
  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, :client,
                  :no_season, :unverified, :access, :locations_types, :import_id, :photo_url, :user, :user_id,
                  :category_mask
  attr_accessor :import_link
  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  reverse_geocoded_by :lat, :lng do |obj,results|
    if geo = results.first
      obj.city = geo.city
      obj.state = geo.state
      obj.country = geo.country
    end
  end
  before_validation { |record| 
    begin
      record.geocode if (record.lat.nil? or record.lng.nil?) and (!record.address.nil?) 
      record.reverse_geocode unless record.lat.nil? or record.lng.nil?  
    rescue
      # if geocoding throws an error, ignore it
    end
  }
  # manually update postgis location object
  after_validation { |record| record.location = "POINT(#{record.lng} #{record.lat})" unless [record.lng,record.lat].any? { |e| e.nil? } }
  # manually update type mask
  after_validation { |record| record.category_mask = record.types.collect{ |t| t.category_mask }.inject(:|) }

  public 

  Months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
  Ratings = ["Poor","Fair","Good","Very Good","Excellent"]
  Fruiting = ["Flowering","Fruiting","Ripe"]
  AccessShort = ["Added by owner","Permitted by owner","Public","Private but overhanging","Private"]
  AccessModes = ["I own this source",
                 "I have permission from the owner to add this source",
                 "Source is on public land",
                 "Source is on private property but overhangs public land",
                 "Source is on private property (ask before you pick)"]
  AccessStatements = ["This source was added by the property owner.",
                      "The owner of this source asked that it be added.",
                      "This source is on public land.",
                      "This source is on private property but may overhang public land. Please pick with discretion.",
                      "This source is on private property. Please ask for permission before you pick."]

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
    author
    photo_url
  end

  def has_photos?
    self.observations.any?{ |o| !o.photo_file_size.nil? }
  end

  # NOTE: hack to always round up (1.5 => 2)
  def mean_yield_rating
    y = self.observations.collect{ |o| o.yield_rating }.compact
    y.length == 0 ? nil : (y.sum.to_f/y.length).ceil
  end
  
  def mean_quality_rating
    q = self.observations.collect{ |o| o.quality_rating }.compact
    q.length == 0 ? nil : (q.sum.to_f/q.length).ceil
  end
  
  # WARNING: Simple ordering, ignores the fact that seasonality may wrap to next calendar year
  def nobs_months_flowering
    m = self.observations.reject{ |o| 
          o.fruiting.nil? or o.fruiting != 0 or o.observed_on.nil? 
        }.collect{ |o| o.observed_on.month - 1 }.sort.group_by{|x| x}.collect{ |k,v| [k,v.length] }
  end
  
  def nobs_months_fruiting
    m = self.observations.reject{ |o| 
      o.fruiting.nil? or o.fruiting != 1 or o.observed_on.nil?
    }.collect{ |o| o.observed_on.month - 1 }.sort.group_by{|x| x}.collect{ |k,v| [k,v.length] }
  end
  
  def nobs_months_ripe
    m = self.observations.reject{ |o| 
      o.fruiting.nil? or o.fruiting != 2 or o.observed_on.nil?
    }.collect{ |o| o.observed_on.month - 1 }.sort.group_by{|x| x}.collect{ |k,v| [k,v.length] }
  end

  def title
    lt = self.locations_types
    if lt.empty?
      nil
    elsif lt.length == 2
      "#{lt[0].name} & #{lt[1].name}"
    elsif lt.length > 2
      "#{lt[0].name} & Others"
    elsif lt.length == 1
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

  def self.build_from_csv(row,typehash=nil)
    type,type_other,desc,lat,lng,address,season_start,season_stop,no_season,
      access,unverified,yield_rating,quality_rating,author,photo_url = row

    loc = Location.new

    unless type.nil? or type.strip.length == 0
      type.split(/[;,:]/).each{ |t|
        safer_type = t.squish.tr('^A-Za-z- \'','').capitalize
        if typehash.nil?
          types = Type.where("name=?",safer_type)
        else
          types = [typehash[safer_type]].compact
        end
        if types.count == 0
          nt = Type.new
          nt.name = safer_type
          nt.save
          typehash[nt.name] = nt
          
          lt = LocationsType.new
          lt.type = nt
          lt.save

          loc.locations_types.push lt
        else
          lt = LocationsType.new
          lt.type = types.shift
          lt.save
          loc.locations_types.push lt
        end
      }
    end

    type_other.split(/[;,:]/).each{ |to|
      lt = LocationsType.new
      lt.type_other = to
      lt.save          
      loc.locations_types.push lt
    } unless type_other.nil? or type_other.strip.length == 0

    unless lat.blank? or lng.blank?
      loc.lat = lat.to_f
      loc.lng = lng.to_f
    end

    loc.access = (access.to_i - 1) unless access.blank?
    loc.description = desc.gsub(/(\\n|<br>)/,"\n") unless desc.blank?
    loc.address = address unless address.blank?
    loc.season_start = (season_start.to_i - 1) unless season_start.blank?
    loc.season_stop = (season_stop.to_i - 1) unless season_stop.blank?
    no_season = no_season.nil? ? "" : no_season.strip.downcase.tr('^a-z','')
    unverified = unverified.nil? ? "" : unverified.strip.downcase.tr('^a-z','')
    loc.no_season = true if no_season == 't' or no_season == "true" or no_season == "x"
    loc.unverified = true if unverified == 't' or unverified == "true" or unverified == "x"
    loc.author = author unless author.blank?

    unless yield_rating.blank? and quality_rating.blank? and photo_url.blank?
      obs = Observation.new
      obs.observed_on = Date.today
      obs.yield_rating = (yield_rating.to_i - 1) unless yield_rating.blank?
      obs.quality_rating = (quality_rating.to_i - 1) unless quality_rating.blank?
      obs.location = loc
      begin
        obs.photo = open(photo_url) unless photo_url.blank?
      rescue
      end
      obs.save
    end

    return loc 
  end

end
