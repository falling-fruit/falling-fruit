class UpdateS3PhotoUrls < ActiveRecord::Migration
  def up
    # Update URLs in `photos` table
    execute <<-SQL
      update photos set
        thumb = replace(
          thumb,
          'https://s3.us-west-2.amazonaws.com/ff-production/',
          'https://ff-production.s3.us-west-2.amazonaws.com/'
        ),
        medium = replace(
          medium,
          'https://s3.us-west-2.amazonaws.com/ff-production/',
          'https://ff-production.s3.us-west-2.amazonaws.com/'
        ),
        original = replace(
          original,
          'https://s3.us-west-2.amazonaws.com/ff-production/',
          'https://ff-production.s3.us-west-2.amazonaws.com/'
        )
      where original like 'https://s3.us-west-2.amazonaws.com/ff-production/%';
    SQL
    # Update URLs in triggers
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
          'https://ff-production.s3.us-west-2.amazonaws.com/observations/photos/' || substring(lpad(NEW.id::text, 9, '0') from 1 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 4 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 7 for 3) || '/thumb/' || NEW.photo_file_name,
          'https://ff-production.s3.us-west-2.amazonaws.com/observations/photos/' || substring(lpad(NEW.id::text, 9, '0') from 1 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 4 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 7 for 3) || '/medium/' || NEW.photo_file_name,
          'https://ff-production.s3.us-west-2.amazonaws.com/observations/photos/' || substring(lpad(NEW.id::text, 9, '0') from 1 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 4 for 3) || '/' || substring(lpad(NEW.id::text, 9, '0') from 7 for 3) || '/original/' || NEW.photo_file_name
        );
        RETURN NEW;
      END;
      $$;
      CREATE OR REPLACE TRIGGER add_observation_photo_trigger
      AFTER INSERT ON observations
      FOR EACH ROW
      WHEN (NEW.photo_file_name IS NOT NULL)
      EXECUTE PROCEDURE add_observation_photo();
    SQL
  end
end
