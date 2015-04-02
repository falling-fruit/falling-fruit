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
    @default_categories = mask_to_array(@import.default_category_mask, Type::Categories)
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
    @import.default_category_mask = array_to_mask(params["default_categories"], Type::Categories)
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
    @import.locations.each{ |l| cluster_decrement(l) } # FIXME: way slow if there's lots of points
    Location.delete_all(["import_id = ?",@import.id])
    @import.destroy
    respond_to do |format|
      format.html { redirect_to imports_url }
      format.json { head :no_content }
    end
  end
  
end