![Status](https://img.shields.io/badge/Status-Inactively%20maintained-yellowgreen.svg?style=flat-square)

Falling Fruit Legacy
====================

This is a Rails 3 web application ([`/app`](/app)) and v0.1 of the API for Falling Fruit, built for use with a PostgreSQL + PostGIS database.

### Who is responsible?

Falling Fruit co-founders Caleb Phillips and Ethan Welty. More info at [fallingfruit.org/about](http://fallingfruit.org/about).

### How can I help?

If you want to help with development, feel free to fork the project. If you have something to submit upstream, send a pull request from your fork. Cool? Cool!

## Status

The website is live at [fallingfruit.org](https://fallingfruit.org). However, maintaining both a website and a mobile app that do not share any code proved too time consuming, and we are very slowly phasing out this project in favor of a mobile-friendly web app ([falling-fruit-web](https://github.com/falling-fruit/falling-fruit-web)). All versions of the mobile app still rely on API v0.1.

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
  brew install postgresql@9.5
  ```

  * PostGIS (2.2.2): [installation instructions](http://postgis.net/install/)

  ```
  brew install postgis
  ```

  * Bundler (1.17.3): [installation instructions](http://bundler.io/)

  ```
  gem install bundler -v 1.17.3
  ```

  * Install project gems:

  ```
  gem install therubyracer -v 0.12.2
  bundle install
  ```

  * Initialize configuration files:

  ```
  cp config/database.yml.dist config/database.yml
  cp config/s3.yml.dist config/s3.yml
  cp config/initializers/credentials.rb.dist config/initializers/credentials.rb
  cp config/initializers/secret_token.rb.dist config/initializers/secret_token.rb
  ```

  Edit `config/database.yml` with your desired development database name, username, and password.
  You will need to add Amazon S3 and Google API credentials to `config/s3.yml` and `config/initializers/credentials.rb`.

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

  * Create an API key:

  Calls to the API will require an api_key parameter that matches an entry in the api_keys database table. You can create one from the rails console.

  ```
  rails console
  ApiKey.create(api_key: 'AKDJGHSD')
  exit
  ```

  Finally, install and start the NodeJS API: see ([falling-fruit-api](https://github.com/falling-fruit/falling-fruit-api)).

  You can test the API by visiting [localhost:3300/api/0.3/types?api_key=AKDJGHSD](http://localhost:3300/api/0.3/types?api_key=AKDJGHSD). The page should return `[]` until you create a new type at [localhost:3000/types/new](http://localhost:3000/types/new).

## Translations

### For translators

Translations of the website interface are managed via the PhraseApp project [Falling Fruit (web)](https://phraseapp.com/accounts/falling-fruit/projects/falling-fruit-web/).
To contribute, contact us ([info@fallingfruit.org](mailto:info@fallingfruit.org)) and we'll add you as a translator to the project.
Species common names are machine-translated and stored directly in the database.

### For developers

Install the PhraseApp CLI:

```
brew tap phrase/brewed
brew install phraseapp
cp .phraseapp.yml.dist .phraseapp.yml
```

Edit `.phraseapp.yml`, and replace `YOUR_ACCESS_TOKEN` with your
[PhraseApp access token](https://phraseapp.com/settings/oauth_access_tokens).

Adding a new translation is easy!

*Step 1*: Add the new translation key on PhraseApp.

Browse to the [Falling Fruit (web)](https://phraseapp.com/accounts/falling-fruit/projects/falling-fruit-web/)
project, select the default locale (English/en), and add a new translation key.
If the same word or phrase appears often, add it as `glossary.<key name>` to avoid
making many keys with identical or derived (pluralized, capitalized, etc) values.

*Step 2*: Update your translation files.

Provided you've setup the PhraseApp CLI (instructions above), run:

```
phraseapp pull
```

This will update the translation files in `config/locales/*.yml`.

*Step 3*: Replace the string in your template with the translation key.

```html
<!-- Instead of adding text to the markup: -->
<span>Map</span>

<!-- Evoke the translation key value with translate() -->
<span><%= translate("glossary.map") %></span>
```
