class AddUkName < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column uk_name text;
    SQL
  end

  def down
    execute <<-SQL
      alter table types drop column uk_name;
    SQL
  end
end
