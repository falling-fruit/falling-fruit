class Type < ActiveRecord::Base
  attr_accessible :name, :marker, :scientific_name, :usda_symbol, :wikipedia_url, :notes, 
                  :edability, :synonyms, :scientific_synonyms, :urban_mushrooms_url, 
                  :eat_the_weeds_url, :fruitipedia_url, :foraging_texas_url, :parent_id, :parent,
                  :es_name, :pl_name, :he_name
  has_attached_file :marker
  validates :name, :presence => true
  has_many :locations_types
  has_many :locations, :through => :locations_types
  belongs_to :parent, class_name: "Type"
  has_many :children, class_name: "Type", foreign_key: "parent_id"

  Ranks={0 => "Species", 1 => "Genus", 2 => "Family", 3 => "Order", 4 => "Class", 5 => "Phylum", 6 => "Kingdom"}
  Edabilities={-1 => "Not worth it (or toxic)", 1 => "Include", 2 => "Maybe Include"}

  def all_children
    c = []
    todo = [self]
    while not todo.empty?
      t = todo.shift
      c += t.children
      todo += t.children
    end
    c
  end

  def usda_profile_url
    self.usda_symbol.nil? ? nil : "http://plants.usda.gov/java/profile?symbol=#{usda_symbol}"
  end

  def full_name(lang=nil)
    n = lang.nil? ? self.name : ([self["#{lang}_name"],self.name].compact.first)
    self.scientific_name.to_s == '' ? n : (n + " [" + self.scientific_name + "]")
  end

  # http://www.i18nguy.com/unicode/language-identifiers.html
  Languages = {"en-us" => "English (US)","la" => "Latin"}
  def il8n_name(lang="en-us")
    return self.name if lang == "en-us" or lang == "en" or lang.nil?
    lang = "scientific" if lang == "la"
    return ([self["#{lang}_name"],self.name].compact.first)
  end

  # csv support
  comma do
    id
    name
    scientific_name
    usda_symbol
    wikipedia_urls
    synonyms
    edability
    notes
  end

end
