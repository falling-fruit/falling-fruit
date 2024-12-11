class AddDatesToRefreshTokens < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table refresh_tokens add column created_at timestamp not null default now();
      alter table refresh_tokens add column updated_at timestamp not null default now();
      -- For existing records, calculate from exp (seconds since the epoch)
      update refresh_tokens set created_at = to_timestamp(exp) - interval '30 days';
      update refresh_tokens set updated_at = created_at;
    SQL
  end

  def down
    execute <<-SQL
      alter table refresh_tokens drop column created_at;
      alter table refresh_tokens drop column updated_at;
    SQL
  end
end
