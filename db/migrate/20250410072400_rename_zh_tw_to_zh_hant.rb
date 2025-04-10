class RenameZhTwToZhHant < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column zh_hant_name text;
      update types set zh_hant_name = zh_tw_name;
      alter table types drop column zh_tw_name;
    SQL
  end

  def down
    execute <<-SQL
      alter table types add column zh_tw_name text;
      update types set zh_tw_name = zh_hant_name;
      alter table types drop column zh_hant_name;
    SQL
  end
end
