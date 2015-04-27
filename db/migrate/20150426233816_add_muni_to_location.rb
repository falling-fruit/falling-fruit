class AddMuniToLocation < ActiveRecord::Migration
  def change
    add_column :locations, :muni, :boolean, :default => false
    execute "UPDATE locations SET muni=imports.muni FROM imports WHERE locations.import_id=imports.id;"
    execute "CREATE INDEX locations_muni_idx ON locations(muni);"
    execute "CREATE INDEX locations_import_idx ON locations(import_id);"
    execute "CREATE INDEX locations_type_idx ON locations(type_ids);"
  end
end
