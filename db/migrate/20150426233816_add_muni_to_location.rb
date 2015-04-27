class AddMuniToLocation < ActiveRecord::Migration
  def change
    add_column :locations, :muni, :boolean, :default => false
    execute "UPDATE locations SET muni=imports.muni FROM imports WHERE locations.import_id=imports.id;"
  end
end
