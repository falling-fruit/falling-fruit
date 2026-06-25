![Status](https://img.shields.io/badge/Status-Not%20maintained-yellow.svg?style=flat-square)

Falling Fruit Legacy
====================

This is a Rails 3 web application and API for Falling Fruit, built for use with a PostgreSQL + PostGIS database.

### Who is responsible?

Falling Fruit co-founders Caleb Phillips and Ethan Welty. More info at [fallingfruit.org/about](http://fallingfruit.org/about).

### How can I help?

If you want to help with development, feel free to fork the project. If you have something to submit upstream, send a pull request from your fork. Cool? Cool!

## Status

The website is still live at [old.fallingfruit.org](https://old.fallingfruit.org) but is being phased out by the new https://fallingfruit.org ([falling-fruit-web](https://github.com/falling-fruit/falling-fruit-web)). It is still used by older mobile app installations and for some admin tools which are not implemented in the new website. The repository is still used for database management, which has not yet been migrated to [falling-fruit-api](https://github.com/falling-fruit/falling-fruit-api).

# Development

## Install PostgreSQL, Ruby, and dependencies

[PostgreSQL](https://www.postgresql.org/download) (15) & [PostGIS](https://postgis.net/install) (3.3), for example with [Homebrew](https://brew.sh):

```sh
brew install postgresql@15 postgis
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
cp .phraseapp.yml.dist .phraseapp.yml
```

Add a desired development database name and your database username, password, and port to `config/database.yml`.
Add Amazon S3 and Google API credentials to `config/s3.yml` and `config/initializers/credentials.rb`.
If working with translations, add Phrase credentials to `.phraseapp.yml`.

## Start the app

Create and structure the database, then seed it with [`db/seeds.rb`](db/seeds.rb):

```sh
rake db:create
rake db:migrate
rake db:seed
```

Install and start the [Falling Fruit API](https://github.com/falling-fruit/falling-fruit-api).

Finally, start the web server and navigate to [localhost:3000](http://localhost:3000):

```sh
thin start
```

# Translation

## For translators

Website translations are managed on the Phrase project [Falling Fruit (web)](https://app.phrase.com/accounts/falling-fruit/projects/falling-fruit-web).
To contribute, email us ([info@fallingfruit.org](mailto:info@fallingfruit.org)) and we'll add you as a translator.

## For developers

Install the [Phrase CLI](https://support.phrase.com/hc/en-us/articles/5784093863964-CLI-Installation-Strings-):

```sh
brew install phrase-cli
cp .phraseapp.yml.dist .phraseapp.yml
```

Add your [Phrase access token](https://app.phrase.com/settings/oauth_access_tokens) to `.phraseapp.yml`.

### Add a new translation

In the [Falling Fruit (web)](https://app.phrase.com/accounts/falling-fruit/projects/falling-fruit-web)
project, select the default locale (English/en), and add a new translation key.
If the same word or phrase appears often, add it as `glossary.<key name>`.

Then, update your translation files (in `config/locales/*.yml`):

```sh
phrase pull
```

Use the translation key in your template.

```html
<!-- Instead of adding text to the markup: -->
<span>Map</span>

<!-- Evoke the translation key value with translate() -->
<span><%= translate("glossary.map") %></span>
```
