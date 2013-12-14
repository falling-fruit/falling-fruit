class MoveDataFromLocationsToObservations < ActiveRecord::Migration
  def change
    Location.all.each{ |l|
      next if l.quality_rating.nil? and l.yield_rating.nil?
      o = Observation.new
      o.quality_rating = l.quality_rating
      o.yield_rating = l.yield_rating
      o.observed_on = l.updated_at.to_date
      o.save
      print "."
    }
    puts
    remove_column :locations, :quality_rating
    remove_column :locations, :yield_rating
  end
end
