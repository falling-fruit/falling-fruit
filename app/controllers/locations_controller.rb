class LocationsController < ApplicationController
  # GET /locations
  # GET /locations.json
  def index
    if params[:region_id].nil?
      @region = nil
      if params[:type_id].nil?
        @type = nil
        @locations = Location.all
        @types = @locations.collect{ |l| l.type }.uniq
      else
        @type = Type.find(params[:type_id])
        @locations = Location.find_all_by_type_id(params[:type_id])
        @types = Location.all.collect{ |l| l.type }.uniq
      end
    else
      @region = Region.find(params[:region_id])
      if params[:type_id].nil?
        @type = nil
        @locations = Location.find_all_by_region_id(params[:region_id])
        @types = @locations.collect{ |l| l.type }.uniq
      else
        @type = Type.find(params[:type_id])
        @locations = Location.find_all_by_type_id_and_region_id(params[:type_id],params[:region_id])
        @types = Location.find_all_by_region_id(params[:region_id]).collect{ |l| l.type }.uniq
      end
    end
    @regions = Region.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @locations }
    end
  end

  # GET /locations/1
  # GET /locations/1.json
  def show
    @location = Location.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @location }
    end
  end

  # GET /locations/new
  # GET /locations/new.json
  def new
    @location = Location.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @location }
    end
  end

  # GET /locations/1/edit
  def edit
    @location = Location.find(params[:id])
  end

  # POST /locations
  # POST /locations.json
  def create
    @location = Location.new(params[:location])

    respond_to do |format|
      if (!current_admin.nil? or verify_recaptcha(:model => @location, :message => "ReCAPCHA error!")) and @location.save
        format.html { redirect_to @location, notice: 'Location was successfully created.' }
        format.json { render json: @location, status: :created, location: @location }
      else
        format.html { render action: "new" }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /locations/1
  # PUT /locations/1.json
  def update
    @location = Location.find(params[:id])

    respond_to do |format|
      if (!current_admin.nil? or verify_recaptcha(:model => @location, :message => "ReCAPCHA error!")) and @location.update_attributes(params[:location])
        format.html { redirect_to @location, notice: 'Location was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /locations/1
  # DELETE /locations/1.json
  def destroy
    @location = Location.find(params[:id])
    @location.destroy

    respond_to do |format|
      format.html { redirect_to locations_url }
      format.json { head :no_content }
    end
  end
end
