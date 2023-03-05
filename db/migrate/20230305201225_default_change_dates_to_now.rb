class DefaultChangeDatesToNow < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE changes ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE changes ALTER COLUMN updated_at SET DEFAULT NOW();
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE changes ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE changes ALTER COLUMN updated_at DROP DEFAULT;
    SQL
  end
end
