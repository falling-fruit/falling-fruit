class AddIntarrayExtension < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE EXTENSION intarray;
    SQL
  end

  def down
    execute <<-SQL
      DROP EXTENSION intarray;
    SQL
  end
end
