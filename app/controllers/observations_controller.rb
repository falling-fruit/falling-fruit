class ObservationsController < ApplicationController
  before_filter :authenticate_user!, :only => [:destroy,:delete_photo]
  #before_filter :prepare_for_mobile, :except => []
  authorize_resource :only => [:destroy,:delete_photo]

  def new
    @obs = Observation.new
    @obs.location_id = params[:location_id]
    respond_to do |format|
      format.html # new.html.erb
      format.mobile
    end
  end

  def create
    @obs = Observation.new(params[:observation])
    @obs.user = current_user if user_signed_in?
    if params[:observation][:observed_on].empty?
      @obs.observed_on = Date.today
      params[:observation].delete(:observed_on)
    else
      @obs.observed_on = Timeliness.parse(params[:observation][:observed_on], :format => 'mm/dd/yyyy')
      params[:observation].delete(:observed_on)
    end
    unless params[:verify].blank? or !params[:verify]
      @obs.location.unverified = false
      @obs.location.save
    end
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @obs, 
                                                       :message => "ReCAPCHA error!")
      if test and @obs.save
        log_changes(@obs.location,"visited",@obs)
        format.html { redirect_to @obs.location, notice: 'You review was added successfully.' }
        format.mobile { redirect_to @obs.location, notice: 'You review was added successfully.' }
      else
        format.html { render action: "new" }
        format.mobile { render action: "new" }
      end
    end
  end

  # DELETE /locations/1
  # DELETE /locations/1.json
  def destroy
    @obs = Observation.find(params[:id])
    @obs.destroy
    respond_to do |format|
      format.html { redirect_to :back }
      format.mobile { redirect_to :back }
    end
  end

  def delete_photo
    @obs = Observation.find(params[:id])
    @obs.photo.destroy
    @obs.photo_file_size = nil
    @obs.save
    respond_to do |format|
      format.html { redirect_to :back }
      format.mobile { redirect_to :back }
    end
  end

end
