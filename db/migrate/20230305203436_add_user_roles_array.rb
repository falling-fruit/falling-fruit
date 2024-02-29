class AddUserRolesArray < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE users
      ADD COLUMN IF NOT EXISTS roles text[] NOT NULL
      GENERATED ALWAYS AS (
        CASE
          WHEN roles_mask & x'1'::int > 0 THEN ARRAY['user', 'admin']
          ELSE ARRAY['user']
        END
      )
      STORED;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE users DROP COLUMN roles;
    SQL
  end
end
