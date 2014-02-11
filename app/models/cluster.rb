class Cluster < ActiveRecord::Base
  attr_accessible :center_lat, :center_lng, :count, :grid_point, :grid_size, :method, :muni, :polygon
  belongs_to :type
end
