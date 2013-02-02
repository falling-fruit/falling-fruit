class AddLocationsTypes < ActiveRecord::Migration
  def up
    remove_column :locations, :region_id
    drop_table :regions
    create_table :imports do |t|
      t.string :url
      t.string :name
      t.text :comments
    end
    create_table :locations_types do |t|
      t.integer :location_id
      t.integer :type_id
      t.string :type_other
    end
  end
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
