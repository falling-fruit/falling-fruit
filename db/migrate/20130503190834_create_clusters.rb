class CreateClusters < ActiveRecord::Migration
  def up
    create_table :clusters do |t|
      t.string :method
      t.boolean :muni
      t.float :grid_size
      t.integer :count
      t.integer :zoom
      t.point :cluster_point, :srid => 900913
      t.point :grid_point, :srid => 900913
      t.polygon :polygon, :srid => 900913
      t.timestamps
    end
    change_table :clusters do |t|
      t.index :polygon, :spatial => true
      t.index :cluster_point, :spatial => true
      t.index :grid_point, :spatial => true
    end
  end
  def down
    drop_table :clusters
  end
end
