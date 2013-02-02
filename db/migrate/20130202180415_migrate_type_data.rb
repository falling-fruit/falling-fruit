class MigrateTypeData < ActiveRecord::Migration
  def up
    Location.all.each{ |l|
      lt = LocationsType.new
      lt.type_id = l.type_id
      lt.type_other = l.type_other
      l.locations_types << lt
      lt.save
      l.save
    }
    remove_column :locations, :type_id
    remove_column :locations, :type_other
    change_table :locations do |t|
      t.references :imports
    end
  end

  def down
    change_table :locations do |t|
      t.string :type_other
      t.integer :type_id
    end
    LocationsType.all.each{ |lt|
      lt.location.type_id = lt.type_id
      lt.location.type_other = lt.type_other
      lt.location.save
      LocationsType.delete(lt.id)
    }
    remove_column :locations, :imports_id
  end
end
