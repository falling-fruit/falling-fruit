class LocationsController < ApplicationController
  before_filter :authenticate_admin!, :only => [:destroy]
  caches_action :cluster, :cache_path => Proc.new { |c| c.params }

  def expire_things
    expire_fragment /locations\/cluster\.json/
  end

  def cluster
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    n = params[:n].nil? ? 10 : params[:n].to_i
    g = params[:grid].present? ? params[:grid].to_i : 1
    g = 15 if g > 15
    gsize = 360.0/(16.0*(2.0**(g-3)))
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" : 
      "AND ST_INTERSECTS(location,ST_GeogFromText('POLYGON((#{params[:nelng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:nelat].to_f}))'))"
    ifilter = "AND (import_id IS NULL OR import_id IN (#{Import.where("autoload #{mfilter}").collect{ |i| i.id }.join(",")}))"
    @clusters = []
    if params[:method].present? and params[:method] == "kmeans"
      r = ActiveRecord::Base.connection.execute("SELECT kmeans, count, ST_X(center) as lng, ST_Y(center) as lat
        FROM (SELECT kmeans, count(*), ST_Centroid(ST_MinimumBoundingCircle(ST_Collect(location::geometry))) AS center 
        FROM (SELECT kmeans(ARRAY[lng,lat],#{n}) OVER (), location FROM locations where lng is not null and lat is not null #{ifilter} #{bound}) 
        AS ksub GROUP by kmeans ORDER BY kmeans) AS csub")
    else
      r = ActiveRecord::Base.connection.execute("SELECT count, st_x(center) as lng, st_y(center) as lat 
       FROM (SELECT count(location) as count, ST_Centroid(ST_Collect(location::geometry)) AS center 
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL #{ifilter} #{bound} 
       GROUP BY ST_SnapToGrid(location::geometry,#{gsize},#{gsize})) AS csub")
    end
    r.each{ |row|
        @clusters.push({:title => row["count"],:lat => row["lat"],:lng => row["lng"],
          :picture => "http://gmaps-utility-library.googlecode.com/svn/trunk/markerclusterer/1.0/images/m3.png",
          :width => 66, :height => 65, :marker_anchor => [0,0]})
    } unless r.nil?
    respond_to do |format|
      format.json { render json: @clusters }
    end
  end

  def markers
    max_n = 500
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? nil :
      "ST_INTERSECTS(location,ST_GeogFromText('POLYGON((#{params[:nelng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:nelat].to_f}))'))"
    ifilter = "(import_id IS NULL OR import_id IN (#{Import.where("autoload #{mfilter}").collect{ |i| i.id }.join(",")}))"
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, 
      string_agg(coalesce(lt.type_other,t.name),',') as name from locations l, 
      locations_types lt, types t WHERE lt.location_id=l.id AND (lt.type_id IS NULL OR lt.type_id=t.id) AND #{[bound,ifilter].compact.join(" AND ")} 
      GROUP BY l.id, l.lat, l.lng, l.unverified LIMIT #{max_n}");
    @markers = r.collect{ |row|
      t = row["name"].split(/,/)
      if t.length == 2
        name = "#{t[0]} and #{t[1]}"
      elsif t.length > 2
        name = "#{t[0]} & Others"
      else
        name = t[0]
      end
      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"], 
       :picture => (row["unverified"] == 't') ? "/smdot_grey_shd.png" : "/smdot_red_shd.png",:width => 32, :height => 32,
       :marker_anchor => [0,0]}
    } unless r.nil?
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

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
        if params["import"]["geocode"].present? and params["import"]["geocode"].to_i == 1
          location.geocode
        end
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

  def infobox
    @location = Location.find(params[:id])
    render(:partial => "/locations/infowindow", 
      :locals => {:location => @location}
    )
  end

  # GET /locations
  # GET /locations.json
  def index
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
    respond_to do |format|
      format.html
      format.json { render json: @location }
    end
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
        expire_things
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
        expire_things
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
    expire_things
    respond_to do |format|
      format.html { redirect_to locations_url }
      format.json { head :no_content }
    end
  end
end
