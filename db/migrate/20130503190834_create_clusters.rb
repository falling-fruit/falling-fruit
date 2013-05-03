class CreateClusters < ActiveRecord::Migration
  def change
    create_table :clusters do |t|
      t.string :method
      t.boolean :muni
      t.float :grid_size
      t.integer :count
      t.integer :zoom
      t.float :center_lat
      t.float :center_lng
      t.point :grid_point, :srid => 4326
      t.polygon :polygon, :srid => 4326

      t.timestamps
    end
  end
end
