class ApplicationController < ActionController::Base
  SupportedLocales = ['pt-br','en','es','fr','de','he','pl']

  before_filter :configure_permitted_parameters, if: :devise_controller?
  before_filter :instantiate_controller_and_action_names
  before_filter :set_locale

  protect_from_forgery

  # catch all perms errors and punt to root
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def after_sign_in_path_for(user)
    home_locations_path
  end

  # http://railscasts.com/episodes/199-mobile-devices
  def mobile_device?
    if session[:mobile_param]
      session[:mobile_param] == "1"
    else
      # this hideous thing is from: http://detectmobilebrowsers.com/download/rails
      /(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.match(request.user_agent) || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.match(request.user_agent[0..3])
    end
  end
  helper_method :mobile_device?

  # assumes not muni increments the not muni clusters
  def self.cluster_increment(location,tids=nil)
    found = {}
    tids = location.type_ids if tids.nil?
    muni = (location.import.nil? or (not location.import.muni)) ? false : true
    ml = Location.select("ST_X(ST_TRANSFORM(location::geometry,900913)) as xp, ST_Y(ST_TRANSFORM(location::geometry,900913)) as yp").where("id=?",location.id).first
    Cluster.select("ST_X(cluster_point) as xp, ST_Y(cluster_point) as yp, count, *").where("ST_INTERSECTS(ST_TRANSFORM(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),900913),polygon) AND muni = ? AND (type_id IS NULL or type_id IN (#{tids.join(",")}))",muni).each{ |clust|
    
      # since the cluster center is the arithmetic mean of the bag of points, simply integrate this points' location proportionally
      # e.g., https://en.wikipedia.org/wiki/Moving_average#Cumulative_moving_average
      clust.count += 1
      newx = clust.xp.to_f+((ml.xp.to_f-clust.xp.to_f)/clust.count.to_f)
      newy = clust.yp.to_f+((ml.yp.to_f-clust.yp.to_f)/clust.count.to_f)
      clust.cluster_point = "POINT(#{newx} #{newy})"
      clust.save

      found[clust.type_id] = [] if found[clust.type_id].nil?
      found[clust.type_id] << clust.zoom
    }
    (tids + [nil]).each{ |type_id|
      found_by_type = found[type_id].nil? ? [] : found[type_id]
      cluster_seed(location,(0..12).to_a - found_by_type,false,type_id) unless found_by_type.max == 12
    }
  end
  helper_method :cluster_increment

  # assumes not muni, increments the not muni clusters
  def self.cluster_decrement(location,tids=nil)
    tids = location.type_ids if tids.nil?
    muni = (location.import.nil? or (not location.import.muni)) ? false : true
    ml = Location.select("ST_X(ST_TRANSFORM(location::geometry,900913)) as x, ST_Y(ST_TRANSFORM(location::geometry,900913)) as y").where("id=#{location.id}").first
    tq = tids.empty? ? "" : "OR type_id IN (#{tids.join(",")})"
    Cluster.select("ST_X(cluster_point) as x, ST_Y(cluster_point) as y, count, *").where("ST_INTERSECTS(ST_TRANSFORM(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),900913),polygon) AND muni = ? AND (type_id IS NULL #{tq})",muni).each{ |clust|
      clust.count -= 1
      if(clust.count <= 0)
        clust.destroy
      else
        # since the cluster center is the arithmetic mean of the bag of points, simply integrate this points' location proportionally
        newx = (((clust.count+1).to_f*clust.x.to_f)-ml.x.to_f)/clust.count.to_f
        newy = (((clust.count+1).to_f*clust.y.to_f)-ml.y.to_f)/clust.count.to_f
        clust.cluster_point = "POINT(#{newx} #{newy})"
        clust.save
      end
    }
  end
  helper_method :cluster_decrement

  def self.cluster_seed(location,zooms,muni,type_id)
    earth_radius = 6378137.0
    gsize_init = 2.0*Math::PI*earth_radius
    xo = -gsize_init/2.0
    yo = gsize_init/2.0
    zooms.each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init/(2.0**z2)
      r = ActiveRecord::Base.connection.execute <<-SQL
        SELECT 
        ST_AsText(ST_SETSRID(ST_MakeBox2d(ST_Translate(grid_point,-#{gsize}/2,-#{gsize}/2),
                               ST_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913)) AS poly_wkt, 
        ST_AsText(grid_point) as grid_point_wkt,
        ST_AsText(st_transform(st_setsrid(ST_POINT(#{location.lng},#{location.lat}),4326),900913)) as cluster_point_wkt
        FROM (
          SELECT ST_SnapToGrid(st_transform(st_setsrid(ST_POINT(#{location.lng},#{location.lat}),4326),900913),
                               #{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) AS grid_point
        ) AS gsub
      SQL
      r.each{ |row|
        c = Cluster.new
        c.grid_point = row["grid_point_wkt"]
        c.grid_size = gsize
        c.polygon = row["poly_wkt"]
        c.count = 1
        c.cluster_point = row["cluster_point_wkt"]
        c.zoom = z
        c.method = "grid"
        c.muni = muni
        c.type_id = type_id
        c.save
      } unless r.nil?
    }
  end
  helper_method :cluster_seed

  def log_changes(location,description,observation=nil,author=nil,description_patch=nil,
    former_type_ids=[],former_type_others=[],former_location=nil)
    c = Change.new
    c.location = location
    c.description = description
    c.remote_ip = request.remote_ip
    c.user = current_user if user_signed_in?
    c.observation = observation
    c.description_patch = description_patch
    c.former_type_ids = former_type_ids
    c.former_type_others = former_type_others
    c.former_location = former_location
    # adding an observation
    if author.nil? and not observation.nil?
      c.author = observation.author
    # adding a location
    elsif author.nil? and observation.nil? and description == "added"
      c.author = location.author
    # editing a location
    elsif not author.nil?
      c.author = author
    end
    c.save
  end
  helper_method :log_changes

  def log_api_request(endpoint,n)
    a = ApiLog.new
    a.n = n
    a.endpoint = endpoint
    a.params = Base64.encode64(Marshal.dump(params))
    a.request_method = request.request_method
    a.ip_address = request.remote_ip
    a.api_key = params[:api_key] if params[:api_key].present?
    a.save
  end
  helper_method :log_api_request

  def number_to_human(n)
    if n > 999 and n <= 999999
      (n/1000.0).round.to_s + "K"
    elsif n > 999999
      (n/1000000.0).round.to_s + "M"
    else
      n.to_s
    end
  end
  helper_method :number_to_human

  protected

  # prevent a sneaky person from setting thier roles on creation
  def configure_permitted_parameters
    if self.controller_name == "registrations"
      params["registration"]["user"].delete("roles_mask") if params["registration"].present? and params["user"].present?
      params["user"].delete("roles_mask") if params["user"].present?
    end
  end

  private

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

  def set_locale
    new_locale = extract_locale_from_subdomain || extract_locale_from_url || extract_locale_from_session
    unless new_locale and SupportedLocales.include? new_locale
      I18n.locale = I18n.default_locale
    else
      I18n.locale = new_locale
      session[:locale] = new_locale
    end
  end

  def extract_locale_from_session
    unless session[:locale].nil? or session[:locale].blank?
      session[:locale]
    else
      nil
    end
  end

  def extract_locale_from_subdomain
    host_parts = request.host.split(/\./)
    if (host_parts.length == 3 and host_parts[1] == "fallingfruit") or
      (host_parts.length == 2 and host_parts[1] == "localhost")
      I18n.available_locales.map(&:to_s).include?(host_parts.first) ? host_parts.first : nil
    else
      nil
    end
  end

  def extract_locale_from_url
    return nil unless params.has_key? :locale
    locale = params[:locale].downcase.gsub('_','-')
    I18n.available_locales.map(&:to_s).include?(locale) ? locale : (I18n.available_locales.map(&:to_s).include?(locale[0,2]) ? locale[0,2] : nil)
  end

  def check_api_key!(endpoint)
    @api_key = ApiKey.find_it(params["api_key"])
    unless !@api_key.nil? and @api_key.can?(endpoint)
      respond_to do |format|
        format.json { render json: {"error" => "Not authorized :/"} }
      end
      return false
    end
    return true
  end

end