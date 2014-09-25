class SessionsController < Devise::SessionsController
  def create
    resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    render json: { auth_token: current_user.authentication_token }
  end

  def destroy
    current_user.authentication_token = nil
    super
  end
end