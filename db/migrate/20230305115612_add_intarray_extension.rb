class AddIntarrayExtension < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE EXTENSION IF NOT EXISTS intarray;
    SQL
  end

  def down
    execute <<-SQL
      DROP EXTENSION intarray;
    SQL
  end
end
