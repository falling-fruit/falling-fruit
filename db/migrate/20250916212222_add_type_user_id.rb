class AddTypeUserId < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table types add column user_id integer references users (id) on delete set null;
    SQL
  end

  def down
    execute <<-SQL
      alter table types drop column user_id;
    SQL
  end
end
