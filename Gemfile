source 'http://rubygems.org'

gem 'rails', '3.2.22.5'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'libv8'
  gem 'therubyracer', :platforms => :ruby
  gem 'uglifier'
end

group :development do
  gem 'better_errors'
end

# Testing
group :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'rack-test'
  gem 'test-unit'
end

gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-cookie-rails'
gem 'validates_timeliness'
gem 'timeliness'
gem 'select2-rails'
gem 'jquery-datatables-rails'

gem 'geocoder'
# we use token_authenticable and some other things that
# got changed in devise 3 so it's important to stick to devise 2 for now
gem 'devise'
gem 'thin'
gem 'pg'
gem 'postgres_ext'
gem 'paperclip'
gem 'aws-sdk'
gem 'gmaps4rails'
gem 'recaptcha', :require => "recaptcha/rails"
gem 'comma'
gem 'activerecord-postgis-adapter'

# Authentication stuff
# http://www.phase2technology.com/blog/authentication-permissions-and-roles-in-rails-with-devise-cancan-and-role-model/
gem 'cancan'
gem 'role_model'

# pretty picture previewing
gem 'shadowbox-rails'

# For diffing/patching descriptions
# Dependency rice 4.0.4 failing to install
# gem 'diff_match_patch_native'

# For internationalization
gem 'i18n'
gem 'devise-i18n'
gem 'rails-i18n'
gem 'i18n-js'
gem 'i18n_viz'

# Field sanitation
gem 'attribute_normalizer'

# https://stackoverflow.com/a/67037930
gem 'mimemagic', git: 'https://github.com/mimemagicrb/mimemagic', ref: 'a4b038c6c1b9d76dac33d5711d28aaa9b4c42c66'

gem 'bcrypt'
