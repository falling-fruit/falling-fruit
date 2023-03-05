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

# Development

## Install PostgreSQL, Ruby, and dependencies

[PostgreSQL](https://www.postgresql.org/download) (14) & [PostGIS](https://postgis.net/install) (3.3), for example with [Homebrew](https://brew.sh):

```sh
brew install postgresql@14 postgis
```

[ImageMagick](https://imagemagick.org/script/download.php):

```sh
brew install imagemagick
```

[Ruby](https://www.ruby-lang.org/en/documentation/installation) (2.3.4), for example with [`rbenv`](https://github.com/rbenv/rbenv#installation):

```sh
rbenv install 2.3.4
rbenv shell 2.3.4
```

[Bundler](https://bundler.io) (1.17.3) with RubyGems:

```sh
gem install bundler -v 1.17.3
```

Project gems with Bundler:

```sh
bundle install
```

Initialize the configuration files:

```sh
cp config/database.yml.dist config/database.yml
cp config/s3.yml.dist config/s3.yml
cp config/initializers/credentials.rb.dist config/initializers/credentials.rb
cp config/initializers/secret_token.rb.dist config/initializers/secret_token.rb
```

Add your development database name, username, and password to `config/database.yml`.
Add Amazon S3 and Google API credentials to `config/s3.yml` and `config/initializers/credentials.rb`.

## Create a database (if needed)

Initialize PostgreSQL. For example:

```sh
initdb -D /usr/local/var/postgres/
pg_ctl -D /usr/local/var/postgres/ -l logfile start
```

Create a Falling Fruit database and superuser:

```sh
psql postgres
CREATE ROLE fallingfruit_user WITH PASSWORD 'PASSWORD' LOGIN SUPERUSER CREATEDB;
CREATE DATABASE fallingfruit_db;
GRANT ALL ON DATABASE fallingfruit_db TO fallingfruit_user;
\q
```

_The database name, username, and password should match your settings for the development database in `config/database.yml`._

## Start the app

Migrate the database to the current schema:

```sh
bundle exec rake db:migrate
```

_Using `rake db:schema:load` is not sufficient, as it does not include custom SQL functions._

Start the web server:

```sh
bundle exec thin start
```

Visit [localhost:3000/users/sign_up](http://localhost:3000/users/sign_up) and register an account.

Force-confirm your account (so that you can sign in) and make yourself an admin (so that you have access to all site features):

```sh
bundle exec rails console
user = User.order('created_at').last
user.confirmed_at = '2013-01-01'
user.roles_mask = '3'
user.save
```

Create an API key:

```sh
bundle exec rails console
ApiKey.create(api_key: 'AKDJGHSD')
```

Finally, install and start the [Falling Fruit API](https://github.com/falling-fruit/falling-fruit-api).

# Translation

## For translators

Translations of the website interface are managed via the PhraseApp project [Falling Fruit (web)](https://phraseapp.com/accounts/falling-fruit/projects/falling-fruit-web/).
To contribute, contact us ([info@fallingfruit.org](mailto:info@fallingfruit.org)) and we'll add you as a translator to the project.
Species common names are machine-translated and stored directly in the database.

## For developers

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
