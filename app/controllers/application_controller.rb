class ApplicationController < ActionController::Base
  @categories = Type::DefaultCategories

  before_filter :redirect_to_https
  before_filter :configure_permitted_parameters, if: :devise_controller?
  before_filter :instantiate_controller_and_action_names
  before_filter :set_locale
  before_filter :set_categories
  after_filter :set_access_control_headers

  protect_from_forgery

  def override_categories(categories = Type::DefaultCategories)
    unless categories.nil?
      @categories = categories
    else
      @categories = Type::DefaultCategories
    end
  end

  # catch all perms errors and punt to root
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Headers'] = 'content-type'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE'
  end

  def handle_options_request
    set_access_control_headers
    head(:ok) if request.request_method == "OPTIONS"
  end

  # app/controllers/application_controller.rb
  # http://guides.rubyonrails.org/i18n.html
  def default_url_options(options = {})
    @categories = Type::DefaultCategories if @categories.nil?
    default_options = options.merge({ locale: I18n.locale, c: @categories.join(",") })
    if (params[:i18n_viz].present? and params[:i18n_viz] == 'true')
      default_options.merge!({ i18n_viz: 'true' })
    end
    return default_options
  end

  # used by devise to determine where to send users after login
  def after_sign_in_path_for(user)
    home_locations_path
  end

  # http://railscasts.com/episodes/199-mobile-devices
  def mobile_device?
    if not session.nil? and session[:mobile_param]
      session[:mobile_param] == "1"
    else
      # this hideous thing is from: http://detectmobilebrowsers.com/download/rails
      /(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows ce|xda|xiino/i.match(request.user_agent) || /1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i.match(request.user_agent[0..3])
    end
  end
  helper_method :mobile_device?

  #
  # =================== CHANGES STUFF =================
  #

  def log_changes(location,description,observation=nil,author=nil,description_patch=nil,
    former_type_ids=[],former_location=nil)
    c = Change.new
    c.location = location
    c.description = description
    c.remote_ip = request.headers['CF-Connecting-IP'] || request.remote_ip
    c.user = current_user if user_signed_in?
    c.observation = observation
    c.description_patch = description_patch
    c.former_type_ids = former_type_ids
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
    begin
      a.params = Base64.encode64(Marshal.dump(params))
    rescue StandardError => bang
      a.params = nil
    end
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

  # prevent a sneaky person from setting their roles on creation
  def configure_permitted_parameters
    if self.controller_name == "registrations"
      params["registration"]["user"].delete("roles_mask") if params["registration"].present? and params["user"].present?
      params["user"].delete("roles_mask") if params["user"].present?
    end
  end

  private

  # put the controller and action names in an instance variable
  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
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

  #
  # =================== LOCALE STUFF ========================
  #

  def set_locale
    new_locale = find_matching_locale(extract_locale_from_subdomain || extract_locale_from_url)
    unless new_locale.nil?
      I18n.locale = new_locale
    else
      I18n.locale = I18n.default_locale
    end
  end

  def extract_locale_from_subdomain
    host_parts = request.host.split(/\./)
    if (host_parts.length > 1) and (host_parts[1] == "fallingfruit" or host_parts[1] == "localhost")
      host_parts.first
    else
      nil
    end
  end

  def extract_locale_from_url
    return (params.has_key? :locale) ? params[:locale] : nil
  end

  def find_matching_locale(string)
    return nil if string.nil?
    string = string.gsub('_','-')
    match = I18n.available_locales.find{ |x| x.casecmp(string.to_sym).zero? }
    if match.nil?
      match = I18n.available_locales.find{ |x| x[0,2].casecmp(string[0,2]).zero? }
    end
    return match ? match : nil
  end

  #
  # =================== TYPE CATEGORIES ========================
  #

  def set_categories
    new_categories = extract_categories_from_url
    unless new_categories.nil?
      @categories = new_categories
    else
      @categories = Type::DefaultCategories
    end
  end

  def extract_categories_from_url
    return nil unless params.has_key? :c
    categories = params[:c].split(",")
    return Type::Categories & categories
  end

  #
  # =================== HTTPS STUFF ========================
  #

  # Redirect only if logged in user is arriving at live site with http
  # see http://stackoverflow.com/questions/11252910/rails-redirect-to-https-while-keeping-all-parameters
  def redirect_to_https
    if user_signed_in? and not (request.ssl? || request.local?)
      redirect_to({:protocol => 'https://'}.merge(params), :flash => flash)
    end
  end

  #
  # =================== SELECT2 STUFF ========================
  #

  def s_to_i_array(string, sep = ',')
    result = [string[0..-1].gsub(/\[|\]/,'').split(sep).reject(&:blank?).collect! {|n| n.to_i}].flatten
  end

end
