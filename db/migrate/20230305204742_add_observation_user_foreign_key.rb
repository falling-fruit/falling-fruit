class AddObservationUserForeignKey < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table observations
      add constraint observations_user_id_fkey
      foreign key (user_id) references users (id) on delete set null;
    SQL
  end

  def down
    execute <<-SQL
      alter table observations drop constraint observations_user_id_fkey;
    SQL
  end
end
