class AddRefreshTokens < ActiveRecord::Migration
  def up
    execute <<-SQL
      create table if not exists refresh_tokens (
        id serial primary key,
        user_id integer not null,
        jti text not null,
        exp integer not null,
        foreign key (user_id) references users (id) on delete cascade
      );
      create index if not exists refresh_tokens_user_id_idx on refresh_tokens (user_id);
    SQL
  end

  def down
    execute <<-SQL
      drop index refresh_tokens_user_id_idx;
      drop table refresh_tokens;
    SQL
  end
end
