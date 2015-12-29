class Invasive < ActiveRecord::Base

  belongs_to :type
  attr_accessible :source, :type_id, :region, :type
  validates :type_id, :presence => true

end
