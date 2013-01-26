class AdminsController < ApplicationController
  before_filter :authenticate_admin!

  def index
    if params[:approved] == "false"
      @admins = Admin.find_all_by_approved(false)
    else
      @admins = Admin.all
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @regions }
    end
  end

  def approve
    @admin = Admin.find(params[:id])
    @admin.approved = true
    @admin.save

    respond_to do |format|
      format.html { redirect_to admins_url }
      format.json { head :no_content }
    end
  end

  def destroy
    @admin = Admin.find(params[:id])
    @admin.destroy

    respond_to do |format|
      format.html { redirect_to admins_url }
      format.json { head :no_content }
    end
  end
end
