class StoreLocationChangesAsJson < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE changes
      ADD COLUMN IF NOT EXISTS location json,
      ADD COLUMN IF NOT EXISTS review json;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE changes
      DROP COLUMN location,
      DROP COLUMN review;
    SQL
  end
end
