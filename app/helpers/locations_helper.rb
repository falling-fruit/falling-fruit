module LocationsHelper
  def add_locations_type_link(name, form)
    link_to_function name do |page|
      task = render(:partial => 'locations_type', :locals => { :pf => form, :lt => LocationsType.new })
      page << %{
        var new_locations_type_id = "new_" + new Date().getTime();
        $('types').insert({ bottom: "#{ escape_javascript task }".replace(/new_\\d+/g, new_locations_type_id) });
      }
    end
  end
end
