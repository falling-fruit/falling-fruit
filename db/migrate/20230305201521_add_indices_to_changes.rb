class AddIndicesToChanges < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS changes_created_at_idx ON changes (created_at DESC);
      CREATE INDEX IF NOT EXISTS changes_user_id_idx ON changes (user_id);
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX changes_created_at_idx;
      DROP INDEX changes_user_id_idx;
    SQL
  end
end
