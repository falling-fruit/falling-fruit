class AddAutoClusterToImports < ActiveRecord::Migration
  def change
    add_column :imports, :auto_cluster, :boolean, :default => false
    add_column :imports, :reverse_geocode, :boolean, :default => false
  end
end
