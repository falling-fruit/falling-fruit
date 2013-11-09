class Type < ActiveRecord::Base
  attr_accessible :name, :marker, :scientific_name, :usda_symbol, :wikipedia_url, :notes, 
                  :edability, :synonyms, :scientific_synonyms, :urban_mushrooms_url, 
                  :eat_the_weeds_url, :fruitipedia_url, :foraging_texas_url
  has_attached_file :marker
  validates :name, :presence => true
  has_many :locations_types
  has_many :locations, :through => :locations_types

  Edabilities={-1 => "Not worth it (or toxic)", 1 => "Include", 2 => "Maybe Include"}

  def usda_profile_url
    self.usda_symbol.nil? ? nil : "http://plants.usda.gov/java/profile?symbol=#{usda_symbol}"
  end

  # csv support
  comma do
    id
    name
    scientific_name
    usda_symbol
    wikipedia_url
    synonyms
    edability
    notes
  end

end
