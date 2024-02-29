class AddVietnameseNameToTypes < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column if not exists vi_name text default null;
    SQL
  end
  def down
    execute <<-SQL
      alter table types drop column vi_name text default null;
    SQL
  end
end
