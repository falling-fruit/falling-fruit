class DefaultDatesToNow < ActiveRecord::Migration
  def up
    execute <<-SQL
      ALTER TABLE api_keys ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE api_keys ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE api_logs ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE api_logs ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE clusters ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE clusters ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE locations_routes ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE locations_routes ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE observations ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE observations ALTER COLUMN created_at SET NOT NULL;
      ALTER TABLE observations ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE observations ALTER COLUMN updated_at SET NOT NULL;
      ALTER TABLE problems ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE problems ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE routes ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE routes ALTER COLUMN updated_at SET DEFAULT NOW();
      ALTER TABLE users ALTER COLUMN created_at SET DEFAULT NOW();
      ALTER TABLE users ALTER COLUMN updated_at SET DEFAULT NOW();
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE api_keys ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE api_keys ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE api_logs ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE api_logs ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE clusters ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE clusters ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE locations_routes ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE locations_routes ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE observations ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE observations ALTER COLUMN created_at DROP NOT NULL;
      ALTER TABLE observations ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE observations ALTER COLUMN updated_at DROP NOT NULL;
      ALTER TABLE problems ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE problems ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE routes ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE routes ALTER COLUMN updated_at DROP DEFAULT;
      ALTER TABLE users ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE users ALTER COLUMN updated_at DROP DEFAULT;
    SQL
  end
end
