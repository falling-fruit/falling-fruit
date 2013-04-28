class ChangesController < ApplicationController

  # GET /types
  # GET /types.json
  def index
    @changes = Change.find(:all,:order => "created_at DESC", :limit => 100)
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @changes }
    end
  end

end
