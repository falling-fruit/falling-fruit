class AddInvasiveFieldToLocations < ActiveRecord::Migration
  def up
    prep = IO.read("util/invasives/prepare.sql")
    execute prep
    add_column :locations, :invasive, :boolean, :default => false
    execute "UPDATE locations SET invasive='t' FROM invasives i WHERE type_ids @> ARRAY[i.type_id] and ST_INTERSECTS(location,i.regions);"
  end

  def down
    execute "DELETE FROM invasives WHERE 1=1;"
    remove_column :locations, :invaisve
  end
end
