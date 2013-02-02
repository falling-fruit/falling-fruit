class LocationsType < ActiveRecord::Base
  belongs_to :location
  belongs_to :type
  attr_accessible :type_other
end
