class Import < ActiveRecord::Base
  attr_accessible :name, :url, :comments
  validates :name, :presence => true
  has_many :locations
end
