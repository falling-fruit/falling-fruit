class AddZhHans < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column zh_hans_name text;
    SQL
  end

  def down
    execute <<-SQL
      alter table types drop column zh_hans_name;
    SQL
  end
end
