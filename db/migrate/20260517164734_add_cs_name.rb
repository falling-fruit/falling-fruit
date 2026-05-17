class AddCsName < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column cs_name text;
    SQL
  end

  def down
    execute <<-SQL
      alter table types drop column cs_name;
    SQL
  end
end
