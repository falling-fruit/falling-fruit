class Type < ActiveRecord::Base

  attr_accessible :name, :synonyms,
                  :fr_name, :de_name, :es_name, :pt_br_name, :it_name, :pl_name, :he_name, :el_name,
                  :scientific_name, :scientific_synonyms, :taxonomic_rank,
                  :usda_symbol, :wikipedia_url,
                  :urban_mushrooms_url, :fruitipedia_url, :foraging_texas_url, :eat_the_weeds_url,
                  :edability, :category_mask, :pending,
                  :parent_id, :parent,
                  :marker, :notes
  has_attached_file :marker
  belongs_to :parent, class_name: "Type"
  has_many :children, class_name: "Type", foreign_key: "parent_id"
  has_many :invasives

  normalize_attributes *character_column_symbols
  normalize_attribute :name, :before => [ :squish ] do |value|
    value.is_a?(String) ? value.gsub(/[^[:word:]\s\(\)\-\']/,'') : value
  end
  validates :name, :presence => true

  Ranks={0 => "Polyphyletic", 1 => "Kingdom", 2 => "Phylum", 3 => "Class", 4 => "Order", 5 => "Family",
         6 => "Genus", 7 => "Multispecies", 8 => "Species", 9 => "Subspecies"}
  Edabilities={-1 => "Not worth it (or toxic)", 1 => "Include", 2 => "Maybe include"}
  Categories=["forager","freegan","honeybee","grafter"]
  DefaultCategories=["forager","freegan"]

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
    self.scientific_name.blank? ? n : (n + " [" + self.scientific_name + "]")
  end

  # Default to english name if requested is nil or empty
  def i18n_name(locale = I18n.locale.to_s)
    ([self[Type.i18n_name_field(locale)], self.name].reject(&:blank?).first)
  end

  def Type.ids
    #Rails.cache.fetch('types_ids', :expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      Type.select("id").collect{ |t| t.id }
    #end
  end

  def Type.i18n_name_field(locale = I18n.locale.to_s)
    lang = locale.tr("-","_").downcase
    lang = "scientific" if lang == "la"
    return lang == "en" ? "name" : "#{lang}_name"
  end

  # Type filter 1.0
  def Type.hash_tree(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    Rails.cache.fetch('types_hash_tree' + cat_mask.to_s + I18n.locale.to_s, :expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      $seen = {}
      Type.where("NOT pending AND parent_id is NULL AND (category_mask & ?)>0",cat_mask).default_sort.collect{ |t| t.to_hash(cats) }
    end
  end

  def to_hash(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    $seen = {} if $seen.nil?
    return nil unless $seen[self.id].nil?
    $seen[self.id] = true
    ret = {"id" => self.id, "name" => self.full_name, "children_ids" => self.children_ids}
    cs = self.children.where("(category_mask & ?)>0",cat_mask).default_sort
    ret["children"] = cs.collect{ |c| c.to_hash(cats) }.compact unless cs.empty?
    ret
  end

  # Type filter 2.0 (forthcoming)
  def Type.dyna_tree(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    Rails.cache.fetch('types_dyna_tree' + cat_mask.to_s + I18n.locale.to_s, :expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      $seen = {}
      Type.where("NOT pending AND parent_id is NULL AND (category_mask & ?)>0",cat_mask).default_sort.collect{ |t| t.to_dyna(cats) }
    end
  end

  def to_dyna(cats=DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    $seen = {} if $seen.nil?
    return nil unless $seen[self.id].nil?
    $seen[self.id] = true
    cs = self.children.where("(category_mask & ?)>0",cat_mask).default_sort
    if cs.empty?
      ret = {"key" => self.id, "title" => self.full_name}
    else
      ret = {"key" => self.id.to_s + ".all", "title" => self.full_name}
      ret["children"] = cs.collect{ |c| c.to_dyna(cats) }.compact
      ret["children"].unshift({"key" => self.id, "title" => "..."})
    end
    ret
  end

  # Location types
  def Type.full_list(cats = DefaultCategories)
    cat_mask = array_to_mask(cats,Categories)
    Rails.cache.fetch('types_full_list' + cat_mask.to_s + I18n.locale.to_s, :expires_in => 4.hours, :race_condition_ttl => 10.minutes) do
      Type.where("NOT pending AND (category_mask & ?)>0",cat_mask).default_sort.collect{ |t| t.full_name }
    end
  end

  # Type editing (NO CACHE)
  def Type.full_list_with_ids(cats = DefaultCategories, uncategorized = false, pending = false)
    cat_mask_str = array_to_mask(cats, Categories).to_s
    uncategorized_str = uncategorized ? "OR category_mask = 0" : ""
    pending_str = pending ? "" : "NOT pending AND "
    Type.where(pending_str + "((category_mask & " + cat_mask_str + ") > 0" + uncategorized_str + ")").default_sort.collect{ |t| {:id => t.id, :text => t.full_name} }
  end

  def Type.sorted_with_parents
    Type.joins("LEFT OUTER JOIN types parents_types ON types.parent_id = parents_types.id").
      select("array_to_string(ARRAY[parents_types.name,types.name],'::') as sortme, parents_types.name as parent_name, types.*").
      order(:sortme)
  end

  # Default sorting scheme
  def Type.default_sort
    #Type.order('scientific_name ASC NULLS LAST, taxonomic_rank ASC').sort_by{ |t| t.scientific_name.blank? ? t.i18n_name : '' }
    self.select("*, COALESCE(" + Type.i18n_name_field + ", name) as i18n_name_sql").order("scientific_name ASC NULLS LAST, taxonomic_rank, i18n_name_sql")
  end

  def locations
    Location.where("type_ids @> ARRAY[?]",self.id)
  end

  def children_ids
    self.children.collect{ |t| t.id }
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
