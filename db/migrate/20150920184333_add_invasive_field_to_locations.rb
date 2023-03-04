class AddInvasiveFieldToLocations < ActiveRecord::Migration
  def up
    add_column :locations, :invasive, :boolean, :default => false
    execute "UPDATE locations SET invasive='t' FROM invasives i WHERE type_ids @> ARRAY[i.type_id] and ST_INTERSECTS(location, i.regions);"
  end

  def down
    remove_column :locations, :invaisve
  end
end
