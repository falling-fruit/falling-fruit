class IndexLocations < ActiveRecord::Migration
  def up
    execute <<-SQL
      create index index_locations_on_muni_updated_lng_lat
      on locations (muni, updated_at DESC, lng, lat)
      where not hidden;
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX index_locations_on_muni_updated_lng_lat;
    SQL
  end
end
