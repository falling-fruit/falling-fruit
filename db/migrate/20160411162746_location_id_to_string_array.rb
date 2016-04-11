class LocationIdToStringArray < ActiveRecord::Migration
  def up
    change_column :locations, :original_id, "varchar[] USING (string_to_array(original_id::varchar(255), ','))"
    rename_column :locations, :original_id, :original_ids
  end
#   def down
#     rename_column :locations, :original_ids, :original_id
#     change_column :locations, :original_id, "integer USING (original_id[1]::int)", :default => nil
#   end
end