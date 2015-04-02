class Import < ActiveRecord::Base
  attr_accessible :name, :url, :comments, :autoload, :muni, :license, :auto_cluster, :reverse_geocode, :default_category_mask
  normalize_attributes *character_column_symbols
  validates :name, :presence => true
  has_many :locations
end
