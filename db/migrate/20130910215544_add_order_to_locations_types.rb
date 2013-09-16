class AddOrderToLocationsTypes < ActiveRecord::Migration
  def change
    change_table "locations_types" do |t|
      t.integer "position"
    end
    p = 0
    lid = nil
    LocationsType.order("location_id, id ASC").each{ |lt|
      if lid.nil? or lt.location_id != lid      
        p = 0
        lid = lt.location_id
      end

      lt.position = p
      lt.save
      p += 1
    }
  end
end
