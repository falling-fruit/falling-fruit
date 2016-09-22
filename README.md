Falling Fruit Web
=================

This is a Rails 3 web application for Falling Fruit, live at [fallingfruit.org](https://fallingfruit.org). The PostgreSQL + PostGIS database is accessed over a RESTful JSON API served up at [fallingfruit.org/api](https://fallingfruit.org/api/).

### Who is responsible?

Falling Fruit co-founders Caleb Phillips and Ethan Welty. More info at [fallingfruit.org/about](http://fallingfruit.org/about).

This code is licensed under the [GNU General Public License version 3](http://www.gnu.org/copyleft/gpl.html).
All of Falling Fruit's data, if not otherwise noted, is licensed under a [Creative Commons Attribution Non-Commercial Share-Alike License](http://creativecommons.org/licenses/by-nc-sa/4.0/).

Both licenses require attribution and that derivative works retain the same license. We reserve the right to prohibit use on a project-by-project basis. Please contact us ([info@fallingfruit.org](mailto:info@fallingfruit.org)) if you have any questions.

### How can I help?

If you want to help with development, feel free to fork the project. If you have something to submit upstream, send a pull request from your fork. Cool? Cool!

## Build instructions (website)

### Install Ruby and dependencies

  * Ruby Version Manager (rvm): [installation instructions](https://rvm.io/rvm/install)
  * Ruby (1.9.3):

  ```
  rvm install 1.9.3
  rvm use 1.9.3
  ```

  * PostgreSQL (9.5.4): [installation instructions](https://www.postgresql.org/download/)

  ```
  brew install postgresql
  ```

  * PostGIS (2.2.2): [installation instructions](http://postgis.net/install/)

  ```
  brew install postgis
  ```

  * Bundler: [installation instructions](http://bundler.io/)

  ```
  gem install bundler
  ```

  * Install project gems

  ```
  bundle install
  ```

  If `therubyracer (0.11.4)` fails to install, change the corresponding line in `Gemfile.lock` to `therubyracer (0.12.2)`.

  * Initialize configuration files

  ```
  cp config/database.yml.dist config/database.yml
  cp config/s3.yml.dist config/s3.yml
  cp config/initializers/secret_token.rb.example config/initializers/secret_token.rb
  ```

  Edit `config/database.yml` with your desired development database name, username, and password.

### Prepare database

  * Initialize and start your postgres database:

  ```
  initdb -D /usr/local/var/postgres/
  pg_ctl -D /usr/local/var/postgres/ -l logfile start
  ```

  * Create a Falling Fruit database and superuser:

  ```
  psql postgres
  CREATE ROLE fallingfruit_user WITH PASSWORD 'PASSWORD' LOGIN SUPERUSER CREATEDB;
  CREATE DATABASE fallingfruit_new_db;
  GRANT ALL ON DATABASE fallingfruit_new_db TO fallingfruit_user;
  \q
  ```

  The database, username, and password should match your settings for the development database in `config/database.yml`.

  * Load the database schema:

  If starting from a fresh install, load the full schema:

  ```
  bundle exec rake db:schema:load
  ```

  Or if updating an existing database with the latest schema, run migrations instead:

  ```
  bundle exec rake db:migrate
  ```

  * Now, add a couple required functions to the database:

  ```
  psql fallingfruit_new_db

  /* Function: utmzone(geometry)
  DROP FUNCTION utmzone(geometry);
  Usage: SELECT ST_Transform(the_geom, utmzone(ST_Centroid(the_geom))) FROM sometable; */
  CREATE OR REPLACE FUNCTION utmzone(geometry)
  RETURNS integer AS
  $BODY$
  DECLARE
  geomgeog geometry;
  zone int;
  pref int;
  BEGIN
  geomgeog:= ST_Transform($1,4326);
  IF (ST_Y(geomgeog))>0 THEN
  pref:=32600;
  ELSE
  pref:=32700;
  END IF;
  zone:=floor((ST_X(geomgeog)+180)/6)+1;
  RETURN zone+pref;
  END;
  $BODY$ LANGUAGE 'plpgsql' IMMUTABLE
  COST 100;

  /* Function: ST_Buffer_Meters(geometry, double precision)
  DROP FUNCTION ST_Buffer_Meters(geometry, double precision);
  Usage: SELECT ST_Buffer_Meters(the_geom, num_meters) FROM sometable; */
  CREATE OR REPLACE FUNCTION ST_Buffer_Meters(geometry, double precision)
  RETURNS geometry AS
  $BODY$
  DECLARE
  orig_srid int;
  utm_srid int;
  BEGIN
  orig_srid:= ST_SRID($1);
  utm_srid:= utmzone(ST_Centroid($1));
  RETURN ST_transform(ST_Buffer(ST_transform($1, utm_srid), $2), orig_srid);
  END;
  $BODY$ LANGUAGE 'plpgsql' IMMUTABLE
  COST 100;

  \q
  ```

  Finally, to start the thin web server, run:

  ```
  bundle exec thin start
  ```

  and visit [localhost:3000/users/sign_up](http://localhost:3000/users/sign_up). Register an account, then force-confirm your account and make yourself an admin:

  ```
  psql fallingfruit_new_db
  UPDATE users SET confirmed_at='2013-01-01 00:00:00' WHERE id='1';
  UPDATE users SET roles_mask='3' WHERE id='1';
  \q
  ```

  Don't go too far, you'll now need to get the API working!

## Build instructions (API)

### Install Node and dependencies

  * Node Version Manager (nvm): [installation instructions](https://github.com/creationix/nvm)
  * Node (0.12):

  ```
  nvm install 0.12
  nvm use 0.12
  ```

  * Node packages:

  ```
  cd api
  npm install
  ```

### Prepare API

  * Create an API key:

  Calls to the API will require an api_key parameter that matches an entry in the api_keys database table. You can create one from the rails console.

  ```
  rails console
  ApiKey.create(api_key: 'APIKEY')
  exit
  ```

  * Start the API:

  ```
  pm2 start app.js
  ```

  You can test the API by visiting [localhost:3100/api/0.2/types.json?api_key=APIKEY](http://localhost:3100/api/0.2/types.json?api_key=APIKEY). The page should return `[]` until you create a new type at [localhost:3000/types/new](http://localhost:3000/types/new).

  The API is currently (poorly) documented [here](https://docs.google.com/document/d/1YMA_d6dT0IZjrJuN5ndz7jzrpSiuwFEsnGcqp9gKgo8/).

## Translations

Translations for the website interface are managed via the [falling-fruit](http://www.localeapp.com/projects/public?search=falling-fruit) project on Locale. To contribute, login with your GitHub account and edit the translations directly. We regularly pull translations from the Locale project to Github. Happy translating! Species common name translations are machine-translated and stored directly in the database.
