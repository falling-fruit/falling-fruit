class AddSomeIndexes < ActiveRecord::Migration
  def up
    add_index :locations_types, :location_id
    add_index :locations_types, :type_id
  end

  def down
    remove_index :locations_types, :location_id
    remove_index :locations_types, :type_id
  end
end
