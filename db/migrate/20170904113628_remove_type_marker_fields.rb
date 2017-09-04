class RemoveTypeMarkerFields < ActiveRecord::Migration
  def up
    remove_column :types, :marker_file_name
    remove_column :types, :marker_content_type
    remove_column :types, :marker_file_size
    remove_column :types, :marker_updated_at
  end

  def down
    add_column :types, :marker_file_name, :string
    add_column :types, :marker_content_type, :string
    add_column :types, :marker_file_size, :integer
    add_column :types, :marker_updated_at, :timestamp
  end
end
