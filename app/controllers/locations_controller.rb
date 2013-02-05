class LocationsController < ApplicationController
  before_filter :authenticate_admin!, :only => [:destroy]

  def import
    if request.post? && params[:import][:csv].present?
      infile = params[:import][:csv].read
      n = 0
      errs = []
      text_errs = []
      ok_count = 0
      import = Import.new
      import.name = params[:import][:name]
      import.url = params[:import][:url]
      import.comments = params[:import][:comments]
      import.save
      CSV.parse(infile) do |row| 
        n += 1
        next if n == 1 or row.join.blank?
        location = Location.build_from_csv(row)
        location.import = import
        if location.valid?
          ok_count += 1
          location.save
        else
          text_errs << location.errors
          errs << row
        end
      end
      if errs.any?
        if params["import"]["error_csv"].present? and params["import"]["error_csv"].to_i == 1
          errFile ="errors_#{Date.today.strftime('%d%b%y')}.csv"
          errs.insert(0,Location.csv_header)
          errCSV = CSV.generate do |csv|
            errs.each {|row| csv << row}
          end
          send_data errCSV,
            :type => 'text/csv; charset=iso-8859-1; header=present',
            :disposition => "attachment; filename=#{errFile}.csv"
        else
          flash[:notice] = "#{errs.length} rows generated errors, #{ok_count} worked"
          @errors = text_errs
        end
      else
        flash[:notice] = "Import total success"
      end
    end
  end

  # GET /locations
  # GET /locations.json
  def index
    @center_lat = nil
    @center_lng = nil
    unless params[:center_lat].nil? or params[:center_lng].nil?
      @center_lat = params[:center_lat].to_f
      @center_lng = params[:center_lng].to_f
    end
    @types = LocationsType.all.collect{ |l| l.type }.compact.uniq.sort{ |x,y| x.name <=> y.name }
    if params[:type_id].nil?
      @type = nil
      @locations = Location.where("lat is not null and lng is not null")
    else
      @type = Type.find(params[:type_id])
      @locations = LocationsType.find_all_by_type_id(params[:type_id]).collect{ |lt| lt.location }.compact
    end
    unless params[:search].nil?
      @search = params[:search].tr('^a-zA-Z0-9 ','').downcase
      @locations.collect!{ |l|
        [l.description,l.author,l.title,l.locations_types.collect{ |lt| lt.type.nil? ? lt.type_other : lt.type.name}.join(" ")].join(" ").downcase.include?(@search) ? l : nil
      }.compact!
    end
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @locations }
      format.csv { render :csv => @locations }
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
    @lat = nil
    @lng = nil
    unless params[:lat].nil? or params[:lng].nil?
      @lat = params[:lat].to_f
      @lng = params[:lng].to_f
      @location.lat = @lat
      @location.lng = @lng
    end
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @location }
    end
  end

  # GET /locations/1/edit
  def edit
    @location = Location.find(params[:id])
    @lat = @location.lat
    @lng = @location.lng
  end

  # POST /locations
  # POST /locations.json
  def create
    unless params[:location].nil? or params[:location][:locations_types].nil?
      lts = params[:location][:locations_types].collect{ |dc,data| 
        lt = LocationsType.new
        lt.type_id = data[:type_id] unless data[:type_id] == ""
        lt.type_other = data[:type_other] unless data[:type_other] == ""
        (lt.type_id == nil and lt.type_other.nil?) ? nil : lt 
      }.compact
      params[:location].delete(:locations_types)
    end
    @location = Location.new(params[:location])
    @location.locations_types += lts unless lts.nil?
    respond_to do |format|
      if (!current_admin.nil? or verify_recaptcha(:model => @location, :message => "ReCAPCHA error!")) and @location.save
        if params[:create_another].present? and params[:create_another].to_i == 1
          format.html { redirect_to new_location_path, notice: 'Location was successfully created.' }
        else
          format.html { redirect_to root_path, notice: 'Location was successfully created.' }
          format.json { render json: @location, status: :created, location: @location }
        end
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

    # prevent normal users from changing author
    params[:location][:author] = @location.author unless admin_signed_in?

    # manually update location types :/
    unless params[:location].nil? or params[:location][:locations_types].nil?
      params[:location][:locations_types].each{ |dc,data|
        if dc =~ /^new/
          lt = LocationsType.new
          lt.type_id = data[:type_id] unless data[:type_id] == ""
          lt.type_other = data[:type_other] unless data[:type_other] == ""
          lt.location_id = @location.id   
          lt.save unless lt.type_id.nil? and lt.type_other.nil?
        elsif dc =~ /^update_(\d+)/
          lt = LocationsType.find($1.to_i)
          lt.type_id = data[:type_id] unless data[:type_id] == ""
          lt.type_other = data[:type_other] unless data[:type_other] == ""
          unless lt.type_id.nil? and lt.type_other.nil?
            lt.save
          else
            LocationsType.delete(lt.id)
          end
        end
      }
      params[:location].delete(:locations_types)
    end

    respond_to do |format|
      if (!current_admin.nil? or verify_recaptcha(:model => @location, :message => "ReCAPCHA error!")) and 
         @location.update_attributes(params[:location])
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
    LocationsType.where("location_id=#{params[:id]}").each{ |lt|
      lt.destroy
    }

    respond_to do |format|
      format.html { redirect_to locations_url }
      format.json { head :no_content }
    end
  end
end
