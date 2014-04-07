class AddCategoryMaskToLocation < ActiveRecord::Migration
  def change
    add_column :locations, :category_mask, :integer, :default => 1
    execute <<-SQL
    SELECT bit_or(t.category_mask) AS category_mask, location_id AS id INTO TEMPORARY TABLE temp
      FROM locations l, locations_types lt, types t WHERE lt.location_id=l.id AND lt.type_id=t.id GROUP BY location_id;
    CREATE index tmp_index ON temp(id);
    UPDATE locations SET category_mask = temp.category_mask FROM temp WHERE temp.id=locations.id;
    SQL
  end
end
