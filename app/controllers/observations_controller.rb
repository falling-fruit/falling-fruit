class ObservationsController < ApplicationController
  before_filter :authenticate_user!, :only => [:destroy,:delete_photo]
  authorize_resource :only => [:destroy,:delete_photo]

  def new
    @obs = Observation.new
    @obs.location_id = params[:location_id]
    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    @obs = Observation.new(params[:observation])
    @obs.user = current_user if user_signed_in?
    if params[:observation][:observed_on].blank?
      @obs.observed_on = nil
    else
      @obs.observed_on = Timeliness.parse(params[:observation][:observed_on], :format => 'yyyy-mm-dd')
    end
    unless params[:verify].blank? or !params[:verify]
      @obs.location.unverified = false
      @obs.location.save
    end
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @obs)
      if test and @obs.save
        if @obs.graft
          log_changes(@obs.location,"grafted",@obs)
        else
          log_changes(@obs.location,"visited",@obs)
        end
        format.html { redirect_to @obs.location, notice: I18n.translate("observations.created") }
      else
        format.html { render action: "new" }
      end
    end
  end

  def destroy
    @obs = Observation.find(params[:id])
    @obs.destroy
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end

  def delete_photo
    @obs = Observation.find(params[:id])
    @obs.photo.destroy
    @obs.photo_file_size = nil
    @obs.save
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end

end
