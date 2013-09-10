class AddOrderToLocationsTypes < ActiveRecord::Migration
  def change
    change_table "locations_types" do |t|
      t.integer "position"
    end
    # This is going to be slow...
    nt = Location.count
    n = 0
    Location.all.each{ |l|
      p = 0
      LocationsType.where("location_id = ?",l.id).order("id ASC").each{ |lt|
        lt.position = p
        lt.save
        p += 1
      }
      n += 1
      if n % 10000 == 0
        puts "#{(100.0*n/nt).round}%"
      end
    }
  end
end
