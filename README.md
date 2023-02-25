![Status](https://img.shields.io/badge/Status-Inactively%20maintained-yellowgreen.svg?style=flat-square)

Falling Fruit Legacy
====================

This is a Rails 3 web application ([`/app`](/app)) and v0.2 NodeJS API ([`/api`](/api)) for Falling Fruit, built for use with a PostgreSQL + PostGIS database.

### Who is responsible?

Falling Fruit co-founders Caleb Phillips and Ethan Welty. More info at [fallingfruit.org/about](http://fallingfruit.org/about).

### How can I help?

If you want to help with development, feel free to fork the project. If you have something to submit upstream, send a pull request from your fork. Cool? Cool!

## Status

The website is live at [fallingfruit.org](https://fallingfruit.org) and the NodeJS API at [fallingfruit.org/api/0.2](https://fallingfruit.org/api/0.2). However, maintaining both a website and a mobile app that do not share any code proved too time consuming, and we are slowly phasing out this project in favor of a standalone NodeJS API ([falling-fruit-api](https://github.com/falling-fruit/falling-fruit-api)) and a mobile-friendly web app ([falling-fruit-web](https://github.com/falling-fruit/falling-fruit-web)).

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

This script, run in the console, can be used to mass-translate keys using Google Translate.
For usage, follow the instructions on [this page](https://strajk.me/writings/2014/google-translate-in-phraseapp/).
NOTE: Requires the old PhraseApp translation editor.

```js
var GET_TRANSLATIONS = "Machine translate";
var APPLY_TRANSLATIONS = "Apply translations";
var UNVERIFY_TRANSLATIONS = "Unverify translations (after save)";

function suggestion_button() {
  suggestBtn.attr('value', GET_TRANSLATIONS);
  suggestBtn.one('click', function() {
    var editors = $('.translation-editor');
    var emptyEditors = editors.filter(function () {
      return $(this).find('textarea')[0].value == "";
    });
    var limit = prompt("Number of empty keys to translate (default: all)", emptyEditors.length);
    emptyEditors = emptyEditors.slice(0, parseInt(limit, 10));
    emptyEditors.each(function () {
      $(this).find('.translation-suggest').click();
    });
    suggestBtn.attr('value', APPLY_TRANSLATIONS);
    suggestBtn.one('click', function () {
      emptyEditors.each(function () {
        $(this).find('.suggestion-content.clickable').click();
      });
      suggestBtn.attr('value', UNVERIFY_TRANSLATIONS);
      suggestBtn.one('click', function () {
        emptyEditors.each(function () {
          $(this).find('.unverify-btn').click();
        });
        suggestion_button()
      });
    });
  });
}

var bar = $('#translation-options-bar');
var submitBtn = bar.find('.btn-primary').first();
submitBtn.before("<input id='suggestBtn' class='btn btn-primary'></input>");
var suggestBtn = $('input#suggestBtn').last();
suggestion_button()
```
