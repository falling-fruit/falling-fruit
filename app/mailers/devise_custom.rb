class DeviseCustom < Devise::Mailer   
  helper :application # gives access to all helpers defined within `application_helper`.
  include Devise::Controllers::UrlHelpers # Optional. eg. `confirmation_url`

  def confirmation_instructions(record)
    headers['X-SMTPAPI'] = '{"category": "FF-Rails-DeviseConfirmation"}'
    devise_mail(record, :confirmation_instructions)
  end
end
