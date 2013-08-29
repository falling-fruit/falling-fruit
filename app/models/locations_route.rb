class LocationsRoute < ActiveRecord::Base
  belongs_to :location
  belongs_to :route
  attr_accessible :position
end
