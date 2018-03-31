class ProblemsController < ApplicationController
  before_filter :authenticate_user!, :only => [:index]
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
      test = user_signed_in? ? true : verify_recaptcha(:model => @problem)
      if test and @problem.save
        format.html { render :text => I18n.translate("problems.created") }
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

  def update
    @problem = Problem.find(params[:id])
    params[:problem][:responder] = User.find(params[:responder_id])
    @problem.attributes = params[:problem]
    respond_to do |format|
      # HACK: To force update old problems without emails (which is now required)
      if @problem.save(:validate => false)
        if params[:email_reporter]
          Spammer.respond_to_problem(@problem).deliver
        end
        format.html { redirect_to problems_path, notice: 'Problem was successfully resolved.' }
      else
        format.html { redirect_to problems_path, notice: 'Problem failed to udpate.' }
      end
    end
  end

end
