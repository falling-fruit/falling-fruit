class CreateLocationsRoutes < ActiveRecord::Migration
  def change
    create_table :locations_routes do |t|
      t.references :location
      t.references :route
      t.integer :position

      t.timestamps
    end
    add_index :locations_routes, :location_id
    add_index :locations_routes, :route_id
  end
end
