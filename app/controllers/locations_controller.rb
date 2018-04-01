class LocationsController < ApplicationController
  respond_to :html
  respond_to :json, only: [:update,:create]

  before_filter :authenticate_user!, :only => [:destroy,:enroute,:home]
  before_filter(:only => [:update,:create]) do |controller|
    authenticate_user! if controller.request.format.json?
  end
  authorize_resource :only => [:destroy,:enroute]

  def expire_things
    expire_fragment "pages_data_type_summary_table"
    expire_fragment "pages_about_stats"
  end

  def data
    max_n = 500
    cat_mask = array_to_mask(Type::DefaultCategories,Type::Categories)
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? nil : "NOT locations.muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" :
      "ST_INTERSECTS(location,ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                     ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326))"
    i18n_name_field = "#{I18n.locale.to_s.tr("-","_")}_name"
    @locations = Location.joins("INNER JOIN types ON types.id=ANY(locations.type_ids)").
             joins("LEFT OUTER JOIN imports ON locations.import_id=imports.id").
             select("ARRAY_AGG(COALESCE(#{i18n_name_field}, en_name)) as name, locations.id as id,
                     description, lat, lng, address, season_start, season_stop, no_season, access, unverified,
                     author, import_id, locations.created_at, locations.updated_at, locations.muni").
             where([bound,mfilter,"(types.category_mask & #{cat_mask})>0"].compact.join(" AND ")).
             group("locations.id, imports.muni").limit(max_n)
    respond_to do |format|
      format.json { render json: @locations }
      format.csv {
        csv_data = CSV.generate do |csv|
          cols = ["id","lat","lng","unverified","description","season_start","season_stop",
                  "no_season","quality_rating","yield_rating","author","address","created_at","updated_at",
                  "access","import_link","muni","types"]
          csv << cols
          @locations.each{ |l|

            quality_rating = Location.find(l.id).mean_quality_rating
            yield_rating = Location.find(l.id).mean_yield_rating

            csv << [l.id,l.lat,l.lng,l.unverified,l.description,
                    l.season_start.nil? ? nil : I18n.t("date.month_names")[l.season_start+1],
                    l.season_stop.nil? ? nil : I18n.t("date.month_names")[l.season_stop+1],
                    l.no_season,
                    quality_rating.nil? ? nil : I18n.t("locations.infowindow.rating")[quality_rating],
                    yield_rating.nil? ? nil : I18n.t("locations.infowindow.rating")[yield_rating],
                    l.author,l.address,l.created_at,l.updated_at,
                    l.access.nil? ? nil : I18n.t("locations.infowindow.access_short")[l.access],
                    l.import_id.nil? ? nil : "http://fallingfruit.org/imports/#{l.import_id}",
                    l.import_id.nil? ? false : (l.muni ? true : false),
                    l.name]
          }
        end
        send_data(csv_data,:type => 'text/csv; charset=utf-8; header=present', :filename => 'data.csv')
      }
    end
  end

  def import
    if request.post? && params[:csv].present?
      infile = params[:csv].tempfile
      import = Import.new(params[:import])
      import.default_category_mask = array_to_mask(params["default_categories"], Type::Categories)
      import.save
      filepath = File.join("public","import","#{import.id}.csv")
      FileUtils.cp infile.path, filepath
      FileUtils.chmod 0666, filepath
      flash[:notice] = "Import #{import.id} queued for processing..."
    end
  end

  def infobox
    @location = Location.find(params[:id])
    if params[:c].blank?
      @cat_mask = array_to_mask(["forager","freegan"],Type::Categories)
    else
      @cat_mask = array_to_mask(params[:c].split(/,/),Type::Categories)
    end
    @cat_filter = "(category_mask & #{@cat_mask})>0"
    respond_to do |format|
      format.html { render :partial => "/locations/infowindow", :locals => {:location => @location,:cat_filter=>@cat_filter} }
    end
  end

  # GET /dumpsters
  # GET /freegan
  def freegan_index
    @freegan = true
    params[:c] = 'freegan'
    params[:t] = 'toner-lite'
    index and return
  end

  def invasivore_index
    @invasivore = true
    params[:c] = 'invasivore'
    index and return
  end

  # GET /graftable
  # GET /grafter
  def grafter_index
    @grafter = true
    params[:c] = 'grafter'
    index and return
  end

  # GET /honeybee
  def honeybee_index
    params[:c] = 'honeybee'
    index and return
  end

  # GET /locations/home
  def home
    prepare_for_sidebar if user_signed_in?
    index
  end

  # GET /locations
  # GET /locations.json
  def index
    params[:c] = Type::DefaultCategories.join(",") unless params[:c].present?
    @cat_mask = array_to_mask(params[:c], Type::Categories)
    @cat_filter = "(category_mask & #{@cat_mask})>0"
    @category_types = Type.where(@cat_filter)
    @types_from_category = !params[:f].present?
    if !params[:f].present?
      params[:f] = @category_types.collect{ |t| t.id }.join(",")
    end
    prepare_from_permalink
    respond_to do |format|
      format.html { render "index" } # index.html.erb
      format.json { render json: @locations }
      format.csv { render :csv => @locations }
    end
  end

  def show
    @location = Location.find(params[:id])
    params[:c] = Type::DefaultCategories.join(",") unless params[:c].present?
    @cat_mask = array_to_mask(params[:c], Type::Categories)
    @cat_filter = "(category_mask & #{@cat_mask})>0"
    @category_types = Type.where(@cat_filter)
    @types_from_category = !params[:f].present?
    if @types_from_category
      params[:f] = @category_types.collect{ |t| t.id }.join(",")
    end
    prepare_from_permalink
    respond_to do |format|
      format.html
    end
  end

  # GET /locations/embed
  def embed
    params[:c] = Type::DefaultCategories.join(",") unless params[:c].present?
    if !params[:f].present?
      @cat_mask = array_to_mask(params[:c], Type::Categories)
      @cat_filter = "(category_mask & #{@cat_mask})>0"
      params[:f] = Type.where(@cat_filter).collect{ |t| t.id }.join(",")
    end
    prepare_from_permalink
    @width = params[:width].present? ? params[:width].to_i : 640
    @height = params[:height].present? ? params[:height].to_i : 600
    respond_to do |format|
      format.html { render :layout => false } # embed.html.erb
    end
  end

  # GET /locations/new
  # GET /locations/new.json
  def new
    @location = Location.new
    @location.type_ids = []
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
    end
  end

  # GET /locations/1/edit
  def edit
    @location = Location.find(params[:id])
    @observation = Observation.new
    @lat = @location.lat
    @lng = @location.lng
    respond_to do |format|
      format.html
    end
  end

  # POST /locations
  # POST /locations.json
  def create
    check_api_key!("api/locations/create") if request.format.json?

    # sanitize input parameters
    create_okay = ["author","description","observation","type_ids","lat","lng","season_start","season_stop","no_season","unverified","access"]
    params[:location] = params[:location].delete_if{ |k,v| not create_okay.include? k }

    # hold onto obs params to parse separately
    obs_params = params[:location][:observation]
    params[:location].delete(:observation)

    # start creating things!
    @location = Location.new(params[:location])
    @location.type_ids = normalize_create_types(params)
    @location.user = current_user if user_signed_in?
    unless params[:location].key?(:author)
      @location.author = current_user.name unless (not user_signed_in?) or (current_user.add_anonymously)
    end
    @observation = prepare_observation(obs_params, @location)
    @observation.author = @location.author unless @observation.nil?

    log_api_request("api/locations/create", 1)
    respond_to do |format|
      # FIXME: recaptcha check should go right at the beginning (before doing anything else)
      test = user_signed_in? ? true : verify_recaptcha(:model => @location)
      if test and @location.save and (@observation.nil? or @observation.save)
        cluster_increment(@location)
        log_changes(@location, "added")
        expire_things
        if params[:create_another].present? and params[:create_another].to_i == 1
          format.html { redirect_to new_location_path, notice: I18n.translate('locations.messages.created') }
          format.json { render json: {"status" => 0, "id" => @location.id} }
        else
          format.html { redirect_to @location, notice: I18n.translate('locations.messages.created') }
          format.json { render json: {"status" => 0, "id" => @location.id} }
        end
      else
        format.html { render action: "new", notice: I18n.translate('locations.messages.not_created') }
        format.json { render json: {"status" => 2, "error" => I18n.translate('locations.messages.not_created') + ": #{(@location.errors.full_messages + @observation.errors.full_messages).join(";")}" } }
      end
    end
  end

  # PUT /locations/1
  # PUT /locations/1.json
  def update
    check_api_key!("api/locations/update") if request.format.json?
    @location = Location.find(params[:id])

    # santize input to only legit fields
    update_okay = ["author","description","observation","type_ids","lat",
                   "lng","season_start","season_stop","no_season","unverified","access"]
    params[:location] = params[:location].delete_if{ |k,v| not update_okay.include? k }

    # set aside observations params for manually processing
    obs_params = params[:location][:observation]
    params[:location].delete(:observation)
    @observation = prepare_observation(obs_params,@location)

    # prevent normal users from changing author
    params[:location][:author] = @location.author unless user_signed_in? and current_user.is? :admin

    # set author
    @observation.author = current_user.name unless @observation.nil? or (not user_signed_in?) or (current_user.add_anonymously)
    # overwrite with field setting if given
    @observation.author = params[:author] if not @observation.nil? and params[:author].present? and not params[:author].blank?

    # compute diff/patch so we can undo later
    unless params[:location][:description].nil?
      dmp = DiffMatchPatch.new
      patch = dmp.patch_to_text(dmp.patch_make(params[:location][:description],@location.description.nil? ? '' : @location.description))
    else
      patch = ""
    end
    former_type_ids = @location.type_ids
    former_location = @location.location

    # parse and normalize types
    params[:location][:type_ids] = normalize_create_types(params)

    # FIXME: Only decrement cluster if save is successful
    # decrement cluster (since location may have moved into a different cluster)
    cluster_decrement(@location)

    log_api_request("api/locations/update",1)
    respond_to do |format|
      # FIXME: recaptcha check should go right at the beginning (before doing anything else)
      test = user_signed_in? ? true : verify_recaptcha(:model => @location)
      if test and @location.update_attributes(params[:location]) and (@observation.nil? or @observation.save)
        log_changes(@location,"edited",nil,params[:author],patch,former_type_ids,former_location)
        cluster_increment(@location)
        expire_things
        format.html { redirect_to @location, notice: I18n.translate('locations.messages.updated') }
        format.json { render json: {"status" => 0} }
      else
        cluster_increment(@location) # do increment even if we fail so that clusters don't slowly deplete :/
        format.html { render action: "edit", notice: I18n.translate('locations.messages.not_updated') }
        format.json { render json: {"status" => 2, "error" => I18n.translate('locations.messages.not_updated') + ": #{(@location.errors.full_messages + @observation.errors.full_messages).join(";")}" } }
      end
    end
  end

  # DELETE /locations/1
  # DELETE /locations/1.json
  def destroy
    @location = Location.find(params[:id])
    cluster_decrement(@location)
    @location.destroy
    expire_things
    respond_to do |format|
      format.html { redirect_to locations_url }
    end
  end

  def enroute
    @location = Location.find(params[:id])
    @route = nil
    if params[:route_id].to_i < 0
      @route = Route.new
      @route.name = "Route ##{Route.count + 1}"
      @route.user = current_user
      @route.access_key = Digest::MD5.hexdigest(rand.to_s)
      @route.is_public = true
      @route.transport_type = Route::TransportTypes.index("Walking")
      @route.save
      lr = LocationsRoute.new
      lr.route = @route
      lr.location = @location
      lr.position = 0
      lr.save
    else
      @route = Route.find(params[:route_id])
      lr = LocationsRoute.where("route_id = ? AND location_id = ?",@route.id,@location.id)
      if lr.nil? or lr.length == 0
        lr = LocationsRoute.new
        lr.route = @route
        lr.location_id = @location.id
        max = LocationsRoute.select("MAX(position) as max").where("route_id = ?",@route.id).first.max
        lr.position = max.nil? ? 0 : max.to_i+1
        lr.save
      else
        lr.destroy_all
      end
    end
    respond_to do |format|
      format.html { redirect_to @route }
    end
  end

  private

  # prepare_observation
  #
  # This function does the task of creating an observation from the parameters
  # in a standard way. It also parses the photo data provided from the API, or in the
  # case of standard form submission, deals with the paperclip attachment. It DOES NOT
  # save the observation that it instantiates.
  #
  def prepare_observation(obs_params,loc)
    return nil if obs_params.nil? or obs_params.values.all?{|x| x.blank? }

    # deal with photo data in expected JSON format
    # (as opposed to something already caught and parsed by paperclip)
    unless obs_params["photo_data"].nil?
      tempfile = Tempfile.new("fileupload")
      tempfile.binmode
      data = obs_params["photo_data"]["data"].include?(",") ? obs_params["photo_data"]["data"].split(/,/)[1] : obs_params["photo_data"]["data"]
      tempfile.write(Base64.decode64(data))
      tempfile.rewind
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        :tempfile => tempfile,
        :type => "image/jpeg",
        :filename => "upload.jpg"
      )
      obs_params[:photo] = uploaded_file
      obs_params.delete(:photo_data)
    end
    obs = Observation.new(obs_params)
    obs.observed_on = Date.today if obs.observed_on.nil?
    obs.location = loc
    obs.user = current_user if user_signed_in?
    return obs
  end

  # normalize_create_types
  #
  # This function is a grand unified parser of parameters related to types
  # it expects one or both of:
  #
  # params[:types] - a comma separated list of types (optionally with scientific name in square brackets)
  # params[:location][:type_ids] - either a hash, where the values are IDs, or an array of IDs
  #
  # In the case of the former, any unrecognized types will have new (pending) types created
  # In the case of the latter, only types whose IDs are legal are kept.
  #
  # The function does not modify the params object, and returns a sanitized array of type IDs
  #
  def normalize_create_types(params)
    type_ids = []

    params[:types].split(/\s*,\s*/).uniq.each{ |full_name|
      names = Type.parse_full_name(full_name)
      types = Type.where(scientific_name: names[:scientific_name]).where(
        "COALESCE(#{names[:common_fields].join(", ")})" + (names[:common_name].nil? ? " IS NULL" : " = #{Type.sanitize(names[:common_name])}")
      )
      # If no matches found, add as pending type
      if types.nil? or types.empty?
        type = Type.new
        type.en_name = names[:common_name]
        type.scientific_name = names[:scientific_name]
        type.pending = true
        type.category_mask = params[:c].blank? ?
          array_to_mask(["forager"], Type::Categories) :
          array_to_mask(params[:c].split(/,/), Type::Categories)
        type.save
      else
        # FIXME: What to do if multiple matches?
        type = types.first
      end
      type_ids.push type.id
    } if params[:types].present?

    logger.debug params[:location][:type_ids]

    if params[:location].present? and params[:location][:type_ids].present?
      v = []
      if params[:location][:type_ids].kind_of? Hash
        v = params[:location][:type_ids].values.map{ |x| x.to_i }
      elsif params[:location][:type_ids].kind_of? Array
        v = params[:location][:type_ids].map{ |x| x.to_i }
      else
        # if we couldn't get it in a reasonable format, delete it
        params[:location].delete(:type_ids)
      end
      logger.debug Type.ids
      logger.debug v
      type_ids += (v & Type.ids) if v.length > 0
    end

    logger.debug "TYPES!"
    logger.debug type_ids
    type_ids
  end

  def prepare_for_sidebar
    i18n_name_field = "t.#{I18n.locale.to_s.tr("-","_")}_name"
    rangeq = current_user.range.nil? ? "" : "AND ST_INTERSECTS(l.location,(SELECT range FROM users u2 WHERE u2.id=#{current_user.id}))"
    changes_query = ActiveRecord::Base.connection.execute(
      "SELECT string_agg(COALESCE(
        t.#{Type.i18n_name_field}, t.#{Type.i18n_name_field('en')}, t.scientific_name
      ), ', ') as type_title,
      extract(days from (NOW()-c.created_at)) as days_ago, c.location_id, c.user_id, c.description, c.remote_ip, l.city, l.state,
      l.country, l.lat, l.lng, l.description as location_description, c.author as change_author, l.id
      FROM changes c, locations l, types t
      WHERE t.id=ANY(l.type_ids) AND l.id=c.location_id #{rangeq}
      GROUP BY l.id, c.location_id, c.user_id, c.description, c.remote_ip, c.created_at, c.author ORDER BY c.created_at DESC LIMIT 100");
    @changes = changes_query.collect{ |row| row }
    @my_changes = Change.select('max(created_at) as created_at, user_id, location_id, description').where("user_id = ? and location_id is not null", current_user.id).group("location_id, user_id, description").order('created_at desc').uniq!{ |c| c.location_id }
    @routes = Route.where("user_id = ?", current_user.id)
    @zoom_to_polygon = current_user.range
    @show_sidebar = true
  end

  def prepare_from_permalink
    @perma = {}
    @perma[:zoom] = params[:z].to_i if params[:z].present?
    @perma[:lat] = params[:y].to_f if params[:y].present?
    @perma[:lng] = params[:x].to_f if params[:x].present?
    @perma[:muni] = params[:m] == "true" if params[:m].present?
    @perma[:labels] = params[:l] == "true" if params[:l].present?
    @perma[:type] = params[:t] if params[:t].present?
    @perma[:cats] = params[:c] if params[:c].present?
    @perma[:center_mark] = params[:center_mark] == "true" if params[:center_mark].present?
    @perma[:center_radius] = params[:circle].to_i if params[:circle].present?
    @types = params[:f].present? ? Type.find(params[:f].split(",").collect{ |e| e.to_i }) : []
    # Updates categories if changed by internal redirects (e.g. freegan_index)
    categories = params[:c].split(/,/) if params[:c].present?
    override_categories(categories)
  end

end
