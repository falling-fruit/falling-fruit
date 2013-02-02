class Type < ActiveRecord::Base
  attr_accessible :name, :marker
  has_attached_file :marker
  validates :name, :presence => true
  has_many :locations_types
  has_many :locations, :through => :locations_types
end
