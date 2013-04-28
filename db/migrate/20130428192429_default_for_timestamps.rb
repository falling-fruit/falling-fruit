class DefaultForTimestamps < ActiveRecord::Migration
  def up
    template = "ALTER TABLE %s ALTER COLUMN created_at SET DEFAULT NOW();
                ALTER TABLE %s ALTER COLUMN updated_at SET DEFAULT NOW();"
    ["admins","imports","locations","types"].each{ |t|
      execute sprintf(template,t,t)
    }
  end

  def down
    template = "ALTER TABLE %s ALTER COLUMN created_at SET DEFAULT NULL;
                ALTER TABLE %s ALTER COLUMN updated_at SET DEFAULT NULL;"
    ["admins","imports","locations","types"].each{ |t|
      execute sprintf(template,t,t)
    }
  end
end
