class ReplaceLocationsTypesWithAnArray < ActiveRecord::Migration
  def up
    change_table :locations do |t|
      t.integer :type_ids, :array => true
      t.string :type_others, :array => true
    end
    execute <<-SQL
    WITH type_info AS (
      SELECT location_id, array_agg(type_id) AS type_ids
      FROM locations_types GROUP BY location_id)
    UPDATE locations SET type_ids=t.type_ids FROM type_info t WHERE t.location_id=id;
    SQL
    execute <<-SQL
    WITH type_info AS (
      SELECT location_id, array_agg(type_other) AS type_others
      FROM locations_types GROUP BY location_id)
    UPDATE locations SET type_others=t.type_others FROM type_info t WHERE t.location_id=id;
    SQL
    drop_table :locations_types # scrrrry!
  end

  def down
    # Feeling too lazy to write a reversion
    raise ActiveRecord::IrreversibleMigration
  end
end
