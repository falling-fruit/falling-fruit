class Type < ActiveRecord::Base
  attr_accessible :name, :marker, :scientific_name, :usda_symbol, :wikipedia_url, :notes, 
                  :edability, :synonyms, :scientific_synonyms, :urban_mushrooms_url, 
                  :eat_the_weeds_url, :fruitipedia_url, :foraging_texas_url, :parent_id, :parent,
                  :es_name, :pl_name, :he_name, :taxonomic_rank, :category_mask
  has_attached_file :marker
  validates :name, :presence => true
  has_many :locations_types
  has_many :locations, :through => :locations_types
  belongs_to :parent, class_name: "Type"
  has_many :children, class_name: "Type", foreign_key: "parent_id"

  Ranks={0 => "Polyphyletic", 1 => "Kingdom", 2 => "Phylum", 3 => "Class", 4 => "Order", 5 => "Family",
         6 => "Genus", 7 => "Multispecies", 8 => "Species", 9 => "Subspecies"}
  Edabilities={-1 => "Not worth it (or toxic)", 1 => "Include", 2 => "Maybe Include"}
  Categories=["human","freegan","honeybee"]
  DefaultCategories=["human","freegan"]

  def all_children
    c = []
    seen = []
    todo = [self]
    while not todo.empty?
      t = todo.shift
      seen << t
      c += t.children
      todo += t.children.reject{ |t| seen.include? t }
    end
    c
  end

  def usda_profile_url
    self.usda_symbol.nil? ? nil : "http://plants.usda.gov/java/profile?symbol=#{usda_symbol}"
  end

  def full_name
    n = self.i18n_name
    self.scientific_name.to_s == '' ? n : (n + " [" + self.scientific_name + "]")
  end

  def Type.hash_tree(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    Rails.cache.fetch('types_hash_tree' + cat_mask.to_s,:expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      $seen = {}
      Type.where("parent_id is NULL AND (category_mask & ?)>0",cat_mask).order(:name).collect{ |t| t.to_hash }
    end
  end

  def to_hash(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    $seen = {} if $seen.nil?
    return nil unless $seen[self.id].nil?
    $seen[self.id] = true
    ret = {"id" => self.id, "name" => self.full_name}
    cs = Type.where("parent_id=? AND (category_mask & ?)>0",self.id,cat_mask)
    ret["children"] = cs.collect{ |c| c.to_hash }.compact unless cs.empty?
    ret
  end

  def Type.full_list(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    Rails.cache.fetch('types_full_list' + cat_mask.to_s,:expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      Type.where("(category_mask & ?)>0",cat_mask).order(:name).collect{ |t| t.full_name }
    end
  end

  def Type.full_list_with_ids(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    #Rails.cache.fetch('types_full_list' + cat_mask.to_s,:expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      Type.where("(category_mask & ?)>0",cat_mask).order(:name).collect{ |t| {:id => t.id, :text => t.full_name} }
    #end
  end

  def Type.sorted_with_parents
    Type.joins("LEFT OUTER JOIN types parents_types ON types.parent_id = parents_types.id").
      select("array_to_string(ARRAY[parents_types.name,types.name],'::') as sortme, parents_types.name as parent_name, types.*").
      order(:sortme)
  end

  def i18n_name
    lang = I18n.locale.to_s.tr("-","_")
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
