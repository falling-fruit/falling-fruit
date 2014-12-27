# https://github.com/plataformatec/devise/issues/3031
# http://maverickblogging.com/logout-is-broken-by-default-ruby-on-rails-web-applications/
FallingfruitWebapp::Application.config.session_store :active_record_store
