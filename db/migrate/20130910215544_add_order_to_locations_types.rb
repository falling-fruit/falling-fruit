class AddOrderToLocationsTypes < ActiveRecord::Migration
  class LocationsType < ActiveRecord::Base
    self.table_name = 'locations_types'
  end
  def change
    change_table :locations_types do |t|
      t.integer :position
    end
    puts "Adding Order"
    n = 0
    p = 0
    c = LocationsType.count
    lid = nil
    LocationsType.order("location_id, id ASC").each{ |lt|
      if lid.nil? or lt.location_id != lid
        p = 0
        lid = lt.location_id
      end
      lt.position = p
      lt.save(:validate => false)
      p += 1
      n += 1
      puts "#{100.0*n.to_f/c.to_f}%" if n % 1000 == 0
    }
  end
end
