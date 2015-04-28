require 'role_model'

class User < ActiveRecord::Base
  has_many :locations
  has_many :observations
  has_many :changes

  ROLES = %w[admin forager partner guest grafter]

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :token_authenticatable

  include RoleModel

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :email_confirmation, :password, :password_confirmation, :remember_me, :range,
                  :name, :bio, :roles, :roles_mask, :remember_me, :add_anonymously,
                  :range_updates_email, :announcements_email, :address, :lat, :lng, :range_radius,
                  :location, :range_radius_unit
  
  # Don't normalize passwords, etc:
  normalize_attributes :name, :email, :email_confirmation, :bio, :address
  validates :email, confirmation: true
  validates :range_radius, numericality: {greater_than: 0}, :allow_nil => true

  geocoded_by :address, :latitude => :lat, :longitude => :lng   # can also be an IP address
  before_validation { |record|
    begin
      record.geocode unless record.address.nil?
    rescue
      # if geocoding throws an error, ignore it
    end
  }
  before_validation { |record|
    if !record.range_radius.nil? and record.range_radius_unit == "miles"
      record.range_radius = record.range_radius * 1.60934
      record.range_radius_unit = "km"
    end
  }
  # manually update postgis location object
  after_validation { |record|
    record.location = "POINT(#{record.lng} #{record.lat})" unless [record.lng,record.lat].any? { |e| e.nil? }
  }
  after_update{ |record| create_range_from_radius(record) }
  after_create{ |record| create_range_from_radius(record) }
  before_save :ensure_authentication_token

  roles_attribute :roles_mask
  roles :admin, :forager, :partner, :guest, :grafter

  # https://github.com/ryanb/cancan/wiki/Role-Based-Authorization
  def roles=(roles)
    self.roles_mask = (roles & ROLES).map { |r| 2**ROLES.index(r) }.inject(0, :+)
  end

  def get_range
    return self.range unless range.nil?
    unless self.location.nil? or self.range_radius.nil?

    end
    return nil
  end

  def roles
    ROLES.reject do |r|
      ((roles_mask || 0) & 2**ROLES.index(r)).zero?
    end
  end

  def is?(role)
    roles.include?(role.to_s)
  end

  # make current_user available in Model context
  class << self
    def current_user=(user)
      Thread.current[:current_user] = user
    end

    def current_user
      Thread.current[:current_user]
    end
  end

  def create_range_from_radius(record)
    unless record.range_radius.nil? or record.location.nil?
      ActiveRecord::Base.connection.execute("UPDATE users SET range=ST_Buffer_Meters(location::geometry,range_radius*1000.0) WHERE id=#{record.id}")
    end
  end
end