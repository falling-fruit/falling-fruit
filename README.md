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

  * Install project gems:

  ```
  bundle install
  ```

  * Initialize configuration files:

  ```
  cp config/database.yml.dist config/database.yml
  cp config/s3.yml.dist config/s3.yml
  cp config/initializers/secret_token.rb.example config/initializers/secret_token.rb
  ```

  Edit `config/database.yml` with your desired development database name, username, and password. Since all files (photos) are stored on Amazon S3 servers, you'll need to add Amazon S3 credentials to your `config/s3.yml` file. Contact us ([info@fallingfruit.org](mailto:info@fallingfruit.org)) for a key.

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

  If you have a dump of the production database, it can be copied to your local environment.
  These commands, although slow, have been found to work reliably:

  ```
  # remote
  pg_dump --no-owner fallingfruit_new_db > fallingfruit.latest.dump
  # local
  psql -d fallingfruit_new_db < fallingfruit.latest.dump
  pg_restore --clean --no-owner -d fallingfruit_new_db ~/desktop/fallingfruit.latest.sql
  ```

  Otherwise, load the database schema:

  ```
  bundle exec rake db:schema:load
  ```

  Or if updating an existing database with the latest schema, run migrations instead:

  ```
  bundle exec rake db:migrate
  ```

  If you're proceeding from an empty database, you'll need to add a couple required functions:

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

  * To start the thin web server, run:

  ```
  bundle exec thin start
  ```

  and visit [localhost:3000/users/sign_up](http://localhost:3000/users/sign_up) to register an account.

  * Finally, force-confirm your account (so that you can sign in) and make yourself an admin (so that you have access to all site features):

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
  ApiKey.create(api_key: 'AKDJGHSD')
  exit
  ```

  Then set the `api_key` variable in `/app/assets/javascripts/mapcommon.js`. The key 'AKDJGHSD' is set by default on `localhost` since it is also the testing key for the live version of the API.

  * Start the API:

  ```
  make start
  ```

  You can test the API by visiting [localhost:3100/api/0.2/types.json?api_key=AKDJGHSD](http://localhost:3100/api/0.2/types.json?api_key=AKDJGHSD). The page should return `[]` until you create a new type at [localhost:3000/types/new](http://localhost:3000/types/new).

  The API is currently (poorly) documented [here](https://docs.google.com/document/d/1YMA_d6dT0IZjrJuN5ndz7jzrpSiuwFEsnGcqp9gKgo8/).

### API Versioning

Since we have multiple versions of the mobile app in the wild, using different versions of the API, more care is needed with respect to branching and versioning the API than with other Falling Fruit code. As of 23 September 2016, we are running two versions of the API in parallel:

  - v0.1 ([api-release-0.1](https://github.com/falling-fruit/falling-fruit/tree/api-release-0.1) branch) - A Rails-based API existing entirely within `app/controller/api`. All versions of the mobile app (v0.1 & 0.2) use this version of the API.
  - v0.2 ([api-release-0.2](https://github.com/falling-fruit/falling-fruit/tree/api-release-0.2) branch) - The first version of the NodeJS-based API. The current website uses this version of the API.
  - v0.3 (under construction in master branch) - The next release of the API, which will be NodeJS-based and both the mobile app and website should use it.

API v0.1 will need to persist for the foreseeable future (unless/until we decide to force upgrade all v0.1 and v0.2 installs of the mobile app). API v0.2 can presumably be removed once v0.3 is released since only the website uses it. Starting with API v0.3, we will need to run parallel versions of the API to allow backwards compatibility.

## Translations

Translations for the website interface are managed via the [falling-fruit](http://www.localeapp.com/projects/public?search=falling-fruit) project on Locale. To contribute, login with your GitHub account and edit the translations directly. We regularly pull translations from the Locale project to Github. Happy translating! Species common name translations are machine-translated and stored directly in the database.
