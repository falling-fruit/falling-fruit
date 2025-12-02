class AddRuName < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column ru_name text;
    SQL
  end

  def down
    execute <<-SQL
      alter table types drop column ru_name;
    SQL
  end
end
