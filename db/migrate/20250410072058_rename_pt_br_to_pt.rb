class RenamePtBrToPt < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column pt_name text;
      update types set pt_name = pt_br_name;
      alter table types drop column pt_br_name;
    SQL
  end

  def down
    execute <<-SQL
      alter table types add column pt_br_name text;
      update types set pt_br_name = pt_name;
      alter table types drop column pt_name;
    SQL
  end
end
