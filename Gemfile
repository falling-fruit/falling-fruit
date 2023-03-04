source 'http://rubygems.org'

gem 'rails', '3.2.22.5'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'libv8'
  gem 'therubyracer', :platforms => :ruby
  gem 'uglifier', '>= 1.0.3'
end

# Development
group :development do
  gem 'faker'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'nokogiri'
end

# Testing
group :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'rack-test'
  gem 'test-unit', '~> 3.0'
end

gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-cookie-rails'
gem 'validates_timeliness', '~> 3.0'
gem 'timeliness'
gem 'select2-rails', '~> 3.4.2'
gem 'jquery-datatables-rails'

gem 'geocoder'
# we use token_authenticable and some other things that
# got changed in devise 3 so it's important to stick to devise 2 for now
gem 'devise', "~> 2.1.2"
gem 'thin'
gem 'pg', '~> 0.18'
gem 'yaml_db'
gem 'paperclip', '~> 4.3'
gem 'aws-sdk', '~> 1.5.7'
gem 'gmaps4rails'
gem 'recaptcha', '= 0.4.0', :require => "recaptcha/rails"
gem 'comma', '~> 3.0'
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
gem 'i15r'
gem 'devise-i18n'
gem 'rails-i18n'
gem 'i18n-js'
gem 'i18n_viz'

# Allows us to use postgres native types like arrays
gem 'postgres_ext'

# Field sanitation
gem 'attribute_normalizer'

# https://stackoverflow.com/a/67037930
gem 'mimemagic', git: 'https://github.com/mimemagicrb/mimemagic', ref: 'a4b038c6c1b9d76dac33d5711d28aaa9b4c42c66'

gem 'bcrypt', '~> 3.1.13'
