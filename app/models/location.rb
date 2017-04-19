class Location < ActiveRecord::Base
  include ActionView::Helpers::TextHelper # for word_wrap

  has_many :observations
  has_many :changes, :dependent => :delete_all
  belongs_to :import
  belongs_to :user

  accepts_nested_attributes_for :observations, :reject_if => :all_blank

  normalize_attributes *character_column_symbols
  validates :type_ids, :presence => true
  validates :lat, :numericality => { :greater_than_or_equal_to => -85.0, :less_than_or_equal_to => 85.0 }, :allow_nil => false
  validates :lng, :numericality => { :greater_than_or_equal_to => -180.0, :less_than_or_equal_to => 180.0 }, :allow_nil => false
  validates :access, :numericality => { :only_integer => true }, :allow_nil => true

  attr_accessible :address, :author, :description, :lat, :lng, :season_start, :season_stop, :client,
                  :no_season, :unverified, :access, :type_ids, :import_id, :photo_url, :user, :user_id,
                  :category_mask, :observations_attributes, :destroyed?, :invasive
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
      record.reverse_geocode unless record.lat.nil? or record.lng.nil? or (!record.import.nil? and record.import.reverse_geocode == false)
    rescue
      # if geocoding throws an error, ignore it
    end
  }
  after_validation { |record|
    # require a valid record
    return false unless record.errors.empty?
    # manually update postgis location object
    record.location = "POINT(#{record.lng} #{record.lat})" unless [record.lng,record.lat].any? { |e| e.nil? }
    # update invasiveness bit
    if Invasive.where("ARRAY[?] @> ARRAY[invasives.type_id] AND ST_INTERSECTS(?,invasives.regions)",record.type_ids,record.location).count > 0
      record.invasive = true
    else
      record.invasive = false
    end
  }
  #after_initialize :default_values

  public

  # csv support
  comma do
    scsv_types
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

  def accepted_type_ids
    self.accepted_types.collect{ |t| t.id }
  end

  def pending_type_ids
    self.pending_types.collect{ |t| t.id }
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

  def types(filter=nil)
    # FIXME: cache this result?
    unless self.type_ids.nil? or self.type_ids.compact.empty?
      Type.where("id IN (#{self.type_ids.compact.join(",")})" + (filter.nil? ? "" : "AND #{filter}"))
    else
      []
    end
  end

  def pending_types
    self.types("pending")
  end

  def accepted_types
    self.types("NOT pending")
  end

  def type_names
    self.types.collect{ |t| t.name }.compact
  end

  def pending_type_names
    self.pending_types.collect{ |t| t.name }.compact
  end

  def accepted_type_names
    self.accepted_types.collect{ |t| t.name }.compact
  end

  def title
    lt = self.type_names
    if lt.empty?
      nil
    elsif lt.length == 2
      "#{lt[0]} & #{lt[1]}"
    elsif lt.length > 2
      "#{lt[0]} (+#{lt.length-1})"
    elsif lt.length == 1
      lt[0]
    end
  end

  def scsv_types
    self.types.collect{ |t| t.name }.compact.join(";")
  end

  #### CLASS METHODS ####

  def self.csv_header
    ["Ids","Types","Description","Lat","Lng","Address","Season Start","Season Stop",
     "No Season","Access","Unverified","Yield Rating","Quality Rating","Author","Photo URL"]
  end

  # Expects types = "id: name [scientific_name], ..." (or any subset of those parts)
  def self.build_from_csv(row, default_category_mask = 0)
    ids,types,desc,lat,lng,address,season_start,season_stop,no_season,
      access,unverified,yield_rating,quality_rating,author,photo_url = row

    loc = Location.new
    loc.original_ids = ids.to_s.split(/\s*,\s*/)
    loc.type_ids = []
    unless types.blank?
      types.split(/\s*,\s*/).each{ |t|
        safer_type = t.gsub(/[^[:word:]\s\(\)\-\'\[\]\.:]/,'')
        id = safer_type[/^([0-9]+)/, 1]
        name = safer_type[/(^(?![0-9])|:\s*)([^\[]+)/, 2]
        scientific_name = safer_type[/\[(.+)\]/, 1]
        matching_types = []
        if not id.nil?
          query = "id = " + ActiveRecord::Base.connection.quote(id)
          matching_types = Type.where(query)
        end
        if matching_types.length == 0
          query = ""
          if not name.nil?
            name = name.squish
            query = "lower(name) = " + ActiveRecord::Base.connection.quote(name.downcase)
          end
          if not scientific_name.nil?
            scientific_name = scientific_name.squish
            if query != ""
              query += " and "
            end
            query += "lower(scientific_name) = " + ActiveRecord::Base.connection.quote(scientific_name.downcase)
          end
          if query != ""
            matching_types = Type.where(query)
          end
        end
        if matching_types.length == 0
          new_type = Type.new
          # HACK: Until name (en) is not required, insert placeholder.
          new_type.name = name.nil? ? "Unknown" : name
          new_type.scientific_name = scientific_name
          new_type.category_mask = default_category_mask
          new_type.pending = true
          new_type.save
          loc.type_ids.push(new_type.id)
        elsif matching_types.length == 1
          loc.type_ids.push(matching_types.shift.id)
        else
          # Multiple matches. Return empty!
          loc.type_ids = []
          return loc
        end
      }
    end
    return loc if (loc.type_ids.length == 0)
    loc.type_ids.uniq!

    unless lat.blank? or lng.blank?
      loc.lat = lat.to_f
      loc.lng = lng.to_f
    end

    # NOTE: -1 shifts because input is 1-index but database is 0-index
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
      obs.yield_rating = (yield_rating.to_i - 1) unless yield_rating.blank?
      obs.quality_rating = (quality_rating.to_i - 1) unless quality_rating.blank?
      obs.author = author unless author.blank?
      obs.location = loc
      begin
        obs.photo = open(photo_url) unless photo_url.blank?
      rescue
      end
      obs.save
    end

    return loc
  end

  private

  def default_values
    self["type_ids"] ||= []
  end

end
