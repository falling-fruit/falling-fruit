class AddJaName < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column ja_name text;
    SQL
  end

  def down
    execute <<-SQL
      alter table types drop column ja_name;
    SQL
  end
end
