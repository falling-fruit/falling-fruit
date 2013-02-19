class LocationsType < ActiveRecord::Base
  belongs_to :location
  belongs_to :type
  attr_accessible :type_other

  def name
    self.type.nil? ? self.type_other : self.type.name
  end
end
