class Cluster < ActiveRecord::Base
  attr_accessible :x, :y, :count, :muni, :zoom, :geohash
  belongs_to :type
end
