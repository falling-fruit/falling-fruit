class IndexLocationsOnUser < ActiveRecord::Migration
  def up
    execute <<-SQL
      create index locations_user_id_idx on locations (user_id);
    SQL
  end

  def down
    execute <<-SQL
      drop index locations_user_id_idx;
    SQL
  end
end
