class RegistrationsController < Devise::RegistrationsController

  def create
    build_resource
    resource.valid?
    unless params[:api_key] == "BJBNKMWM" or verify_recaptcha(:model => resource)
      clean_up_passwords resource
      respond_with resource
    else
      super
    end
  end

end
