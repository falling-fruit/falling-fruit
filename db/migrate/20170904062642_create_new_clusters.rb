class CreateNewClusters < ActiveRecord::Migration
  def up
    create_table :new_clusters do |t|
      t.text :geohash, :null => false
      t.boolean :muni, :null => false
      t.column :x, 'real', :null => false
      t.column :y, 'real', :null => false
      t.integer :count, :null => false
      t.integer :zoom, :null => false
      t.references :type, :null => false
      t.timestamps
    end
    add_index :new_clusters, :type_id
  end
  def down
    if ActiveRecord::Base.connection.table_exists? :new_clusters
      drop_table :new_clusters
    end
  end
end
