class AddForeignKeys < ActiveRecord::Migration
  def up
    execute <<-SQL
      -- changes
      -- Make change anonymous on user delete
      ALTER TABLE changes DROP CONSTRAINT IF EXISTS changes_user_id_fkey;
      ALTER TABLE changes ADD CONSTRAINT changes_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL;
      -- added: delete if location deleted
      ALTER TABLE changes DROP CONSTRAINT IF EXISTS changes_location_id_fkey;
      ALTER TABLE changes ADD CONSTRAINT changes_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE;
      -- visited: delete if observation deleted
      ALTER TABLE changes DROP CONSTRAINT IF EXISTS changes_observation_id_fkey;
      ALTER TABLE changes ADD CONSTRAINT changes_observation_id_fkey FOREIGN KEY (observation_id) REFERENCES observations (id) ON DELETE CASCADE;

      -- locations
      -- Make location organic on import delete
      ALTER TABLE locations DROP CONSTRAINT IF EXISTS locations_import_id_fkey;
      ALTER TABLE locations ADD CONSTRAINT locations_import_id_fkey FOREIGN KEY (import_id) REFERENCES imports (id) ON DELETE SET NULL;

      -- problems
      -- Make reporter anonymous on user delete
      ALTER TABLE problems DROP CONSTRAINT IF EXISTS problems_reporter_id_fkey;
      ALTER TABLE problems ADD CONSTRAINT problems_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES users (id) ON DELETE SET NULL;
      -- Make responder anonymous on user delete
      ALTER TABLE problems DROP CONSTRAINT IF EXISTS problems_responder_id_fkey;
      ALTER TABLE problems ADD CONSTRAINT problems_responder_id_fkey FOREIGN KEY (responder_id) REFERENCES users (id) ON DELETE SET NULL;
      -- Leave in place on location delete (just in case)
      ALTER TABLE problems DROP CONSTRAINT IF EXISTS problems_location_id_fkey;
      ALTER TABLE problems ADD CONSTRAINT problems_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL;

      -- observations
      -- Delete observations on location delete (which is why hiding locations is better)
      ALTER TABLE observations DROP CONSTRAINT IF EXISTS observations_location_id_fkey;
      ALTER TABLE observations ADD CONSTRAINT observations_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE;

      -- types
      -- Leave in place on parent delete
      ALTER TABLE types DROP CONSTRAINT IF EXISTS types_parent_id_fkey;
      ALTER TABLE types ADD CONSTRAINT types_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES types (id) ON DELETE SET NULL;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE changes DROP CONSTRAINT changes_user_id_fkey;
      ALTER TABLE changes DROP CONSTRAINT changes_location_id_fkey;
      ALTER TABLE changes DROP CONSTRAINT changes_observation_id_fkey;
      ALTER TABLE locations DROP CONSTRAINT locations_user_id_fkey;
      ALTER TABLE locations DROP CONSTRAINT locations_import_id_fkey;
      ALTER TABLE problems DROP CONSTRAINT problems_reporter_id_fkey;
      ALTER TABLE problems DROP CONSTRAINT problems_responder_id_fkey;
      ALTER TABLE problems DROP CONSTRAINT problems_location_id_fkey;
      ALTER TABLE observations DROP CONSTRAINT observations_location_id_fkey;
      ALTER TABLE types DROP CONSTRAINT types_parent_id_fkey;
    SQL
  end
end
