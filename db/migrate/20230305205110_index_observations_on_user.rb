class IndexObservationsOnUser < ActiveRecord::Migration
  def up
    execute <<-SQL
      create index if not exists observations_user_id_idx on observations (user_id);
    SQL
  end

  def down
    execute <<-SQL
      drop index observations_user_id_idx;
    SQL
  end
end
