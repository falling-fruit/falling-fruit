class AddAddressToUser < ActiveRecord::Migration
  def change
    add_column :users, :address, :text
    add_column :users, :lat, :decimal
    add_column :users, :lng, :decimal
    add_column :users, :range_radius, :decimal
    add_column :users, :range_radius_unit, :string
    change_table :users do |t|
      t.point :location, :geographic => true
    end
    change_table :users do |t|
      t.index :location, :spatial => true
    end
    # http://www.gistutor.com/postgresqlpostgis/6-advanced-postgresqlpostgis-tutorials/58-postgis-buffer-latlong-and-other-projections-using-meters-units-custom-stbuffermeters-function.html
    execute <<-EOSQL
/* Function: utmzone(geometry)
DROP FUNCTION utmzone(geometry);
Usage: SELECT ST_Transform(the_geom, utmzone(ST_Centroid(the_geom))) FROM sometable; */

CREATE OR REPLACE FUNCTION utmzone(geometry)
RETURNS integer AS
$BODY$
DECLARE
geomgeog geometry;
zone int;
pref int;

BEGIN
geomgeog:= ST_Transform($1,4326);

IF (ST_Y(geomgeog))>0 THEN
pref:=32600;
ELSE
pref:=32700;
END IF;

zone:=floor((ST_X(geomgeog)+180)/6)+1;
RETURN zone+pref;
END;
$BODY$ LANGUAGE 'plpgsql' IMMUTABLE
COST 100;

/* Function: ST_Buffer_Meters(geometry, double precision)
DROP FUNCTION ST_Buffer_Meters(geometry, double precision);
Usage: SELECT ST_Buffer_Meters(the_geom, num_meters) FROM sometable; */


CREATE OR REPLACE FUNCTION ST_Buffer_Meters(geometry, double precision)
RETURNS geometry AS
$BODY$
DECLARE
orig_srid int;
utm_srid int;

BEGIN
orig_srid:= ST_SRID($1);
utm_srid:= utmzone(ST_Centroid($1));

RETURN ST_transform(ST_Buffer(ST_transform($1, utm_srid), $2), orig_srid);
END;
$BODY$ LANGUAGE 'plpgsql' IMMUTABLE
COST 100;
EOSQL
  end
end