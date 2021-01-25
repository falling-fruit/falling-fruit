class DeviseCustom < Devise::Mailer
  helper :application # gives access to all helpers defined within `application_helper`.
  include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`
  # default template_path: 'devise_cusom'

  def confirmation_instructions(record)
    headers['X-PM-Tag'] = 'email-confirmation'
    super
  end
end
