class AddPhotos < ActiveRecord::Migration
  def up
    execute <<-SQL
      create table if not exists photos (
        id serial primary key,
        observation_id integer,
        user_id integer,
        created_at timestamp default now() not null,
        updated_at timestamp default now() not null,
        thumb text not null,
        medium text not null,
        original text not null,
        observation_order integer,
        foreign key (observation_id) references observations (id) on delete cascade,
        foreign key (user_id) references users (id) on delete set null
      );
      create index if not exists photos_observation_id_idx on photos (observation_id);
      create index if not exists photos_user_id_idx on photos (user_id);
    SQL
    # Populate `photos` table with existing photo URLs
    execute <<-SQL
      insert into photos (
        observation_id,
        created_at,
        updated_at,
        thumb,
        medium,
        original,
        observation_order,
        user_id
      )
      select
        id as observation_id,
        created_at,
        updated_at,
        base_path || '/thumb/' || photo_file_name as thumb,
        base_path || '/medium/' || photo_file_name as medium,
        base_path || '/original/' || photo_file_name as original,
        1,
        user_id
      from (
        select
          id,
          created_at,
          updated_at,
          photo_file_name,
          'https://s3.us-west-2.amazonaws.com/ff-production/observations/photos/' ||
          substring(lpad(id::text, 9, '0') from 1 for 3) || '/' ||
          substring(lpad(id::text, 9, '0') from 4 for 3) || '/' ||
          substring(lpad(id::text, 9, '0') from 7 for 3) as base_path,
          user_id
        from observations
        where photo_file_name is not null
      ) as temp;
    SQL
    # Add triggers to keep updated
    execute <<-SQL
      CREATE OR REPLACE FUNCTION add_observation_photo()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
      AS
      $$
      BEGIN
        INSERT INTO photos (
          observation_id,
          user_id,
          observation_order,
          thumb,
          medium,
          original
        )
        VALUES (
          NEW.id,
          NEW.user_id,
          1,
          'https://s3.us-west-2.amazonaws.com/ff-production/observations/photos/' || substring(lpad(NEW.id::text, 9, '0') from 1 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 4 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 7 for 3) || '/thumb/' || NEW.photo_file_name,
          'https://s3.us-west-2.amazonaws.com/ff-production/observations/photos/' || substring(lpad(NEW.id::text, 9, '0') from 1 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 4 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 7 for 3) || '/medium/' || NEW.photo_file_name,
          'https://s3.us-west-2.amazonaws.com/ff-production/observations/photos/' || substring(lpad(NEW.id::text, 9, '0') from 1 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 4 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 7 for 3) || '/original/' || NEW.photo_file_name
        );
        RETURN NEW;
      END;
      $$;
      CREATE TRIGGER add_observation_photo_trigger
      AFTER INSERT ON observations
      FOR EACH ROW
      WHEN (NEW.photo_file_name IS NOT NULL)
      EXECUTE PROCEDURE add_observation_photo();
    SQL
  end

  def down
    execute <<-SQL
      drop index photos_observation_id_idx;
      drop index photos_user_id_idx;
      drop table photos;
      drop trigger add_observation_photo_trigger;
      drop function add_observation_photo;
    SQL
  end
end
