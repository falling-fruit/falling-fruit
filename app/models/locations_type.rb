class LocationsType < ActiveRecord::Base
  belongs_to :location
  belongs_to :type
  attr_accessible :type_other, :type, :type_id
  validates :type_other, :presence => true, :if => "type.nil?", :allow_blank => false, :allow_nil => false
  validates_associated :type, :allow_nil => true

  def name
    self.type.nil? ? self.type_other : self.type.i18n_name
  end
end
