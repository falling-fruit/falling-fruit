class Import < ActiveRecord::Base
  attr_accessible :name, :url, :comments, :autoload
  validates :name, :presence => true
  has_many :locations
end
