class Type < ActiveRecord::Base
  attr_accessible :name, :marker, :scientific_name, :usda_symbol
  has_attached_file :marker
  validates :name, :presence => true
  has_many :locations_types
  has_many :locations, :through => :locations_types

  def usda_profile_url
    self.usda_symbol.nil? ? nil : "http://plants.usda.gov/java/profile?symbol=#{usda_symbol}"
  end

  def wikipedia_url
    "http://en.wikipedia.org/wiki/#{self.name}"
  end

end
