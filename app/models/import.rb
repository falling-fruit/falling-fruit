class Import < ActiveRecord::Base
  attr_accessible :name, :url, :comments, :autoload, :muni, :license
  validates :name, :presence => true
  has_many :locations
end
