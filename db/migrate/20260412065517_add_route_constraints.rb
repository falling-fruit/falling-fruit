class AddRouteConstraints < ActiveRecord::Migration
  def up
    execute <<-SQL
      alter table locations_routes add foreign key (route_id) references routes (id) on delete cascade;
      alter table locations_routes add foreign key (location_id) references locations (id) on delete cascade;
      alter table locations_routes add unique (route_id, location_id);
      alter table locations_routes add unique (route_id, position);
      alter table routes add foreign key (user_id) references users (id) on delete cascade;
    SQL
  end

  def down
    execute <<-SQL
      alter table locations_routes drop constraint locations_routes_route_id_fkey;
      alter table locations_routes drop constraint locations_routes_location_id_fkey;
      alter table locations_routes drop constraint locations_routes_route_id_location_id_key;
      alter table locations_routes drop constraint locations_routes_route_id_position_key;
      alter table routes drop constraint routes_user_id_fkey;
    SQL
  end
end
