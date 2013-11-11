class Observation < ActiveRecord::Base
  belongs_to :user
  belongs_to :location
  attr_accessible :yield_rating, :quality_rating, :fruiting, :user_id, :location_id, :location, :user, :id, :photo, :comment, :author, :observed_on
  has_attached_file :photo, :styles => { :medium => "300x300>", :thumb => "100x100>" }
  validates :fruiting, :quality_rating, :yield_rating, :numericality => { :only_integer => true }, :allow_nil => true
  validates_date :observed_on, :allow_nil => true
end
