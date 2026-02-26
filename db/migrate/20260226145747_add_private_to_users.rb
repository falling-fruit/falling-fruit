class AddPrivateToUsers < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table users add column private boolean;
      update users set private = name is null;
      alter table users alter column private set not null;
      alter table users alter column private set default false;
    SQL
  end

  def down
    execute <<-SQL
      alter table users drop column private;
    SQL
  end
end
