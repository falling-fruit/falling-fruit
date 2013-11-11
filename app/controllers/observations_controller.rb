class ObservationsController < ApplicationController
  #before_filter :authenticate_user!, :only => [:destroy]
  #before_filter :prepare_for_mobile, :except => [:cluster,:markers,:marker,:data,:infobox]
  #authorize_resource :only => [:destroy,:enroute]

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
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @obs, 
                                                       :message => "ReCAPCHA error!")
      if test and @obs.save
        log_changes(@obs.location,"visited")
        format.html { redirect_to @obs.location, notice: 'Observation was successfully created.' }
        format.mobile { redirect_to @obs.location, notice: 'Observation was successfully created.' }
      else
        format.html { render action: "new" }
        format.mobile { render action: "new" }
      end
    end
  end

end
