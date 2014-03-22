class ProblemsController < ApplicationController
  before_filter :authenticate_user!, :only => [:index]
  #before_filter :prepare_for_mobile, :except => []
  authorize_resource :only => [:index]


  def new
    @problem = Problem.new
    @problem.location_id = params[:location_id]
    @problem.reporter = current_user if user_signed_in?
    respond_to do |format|
      format.html { render :partial => "/problems/new", :locals => {:problem => @problem} }
    end
  end

  def create
    @problem = Problem.new(params[:problem])
    if user_signed_in?
      @problem.reporter = current_user
      @problem.email = current_user.email
      @problem.name = current_user.name
    end

    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @problem, 
                                                       :message => "ReCAPCHA error!")
      if test and @problem.save
        format.html { render :text => 'Thank you for letting us know!' }
      else
        format.html { render :partial => "/problems/new", :locals => {:problem => @problem} }
      end
    end
  end

  def index
    @open_problems = Problem.where("resolution_code IS NULL")
    @closed_problems = Problem.where("resolution_code IS NOT NULL")
    respond_to do |format|
      format.html
    end
  end

end
