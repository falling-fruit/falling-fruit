class AddRouteDescription < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table routes add column description text;
    SQL
  end

  def down
    execute <<-SQL
      alter table routes drop column description;
    SQL
  end
end
