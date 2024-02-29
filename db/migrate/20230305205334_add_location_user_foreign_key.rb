class AddLocationUserForeignKey < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table locations drop constraint if exists locations_user_id_fkey;
      alter table locations
      add constraint locations_user_id_fkey
      foreign key (user_id) references users (id) on delete set null;
    SQL
  end

  def down
    execute <<-SQL
      alter table locations drop constraint locations_user_id_fkey;
    SQL
  end
end
