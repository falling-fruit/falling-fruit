class AddInaturalistIdToLocation < ActiveRecord::Migration
  def up
    add_column :locations, :inaturalist_id, :integer
  end

  def down
    remove_column :locations, :inaturalist_id
  end
end
