class ImportsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show, :bibliography]
  authorize_resource

  def index
    respond_to do |format|
      format.html # index.html.erb
    end
  end
  
  def edit
    @import = Import.find(params[:id])
  end

  def show
    @import = Import.find(params[:id])
    respond_to do |format|
      format.html
      format.json { render json: @import }
    end
  end

  def update
    @import = Import.find(params[:id])

    respond_to do |format|
      if @import.update_attributes(params[:import])
        format.html { redirect_to imports_path, notice: 'Import was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @import.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @import = Import.find(params[:id])
    @import.locations.each{ |l| ApplicationController.cluster_decrement(l) } # FIXME: way slow if there's lots of points
    LocationsType.delete_all(["location_id IN (SELECT id FROM locations WHERE import_id = ?)",@import.id])
    Location.delete_all(["import_id = ?",@import.id])
    @import.destroy
    respond_to do |format|
      format.html { redirect_to imports_url }
      format.json { head :no_content }
    end
  end
end