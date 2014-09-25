class Import < ActiveRecord::Base
  attr_accessible :name, :url, :comments, :autoload, :muni, :license, :auto_cluster,:reverse_geocode
  validates :name, :presence => true
  has_many :locations
end
