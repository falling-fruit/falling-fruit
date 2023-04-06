class StoreLocationChangesAsJson < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE changes
      ADD COLUMN location json,
      ADD COLUMN review json;
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
