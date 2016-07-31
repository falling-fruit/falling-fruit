puts Benchmark.measure {

## Constants

Earth_radius = 6378137 # meters
Earth_circum = 2 * Math::PI * Earth_radius
Zoom = 13
Grid_size = (2 ** Zoom) # size of grid in cells
Cell_size = Earth_circum / Grid_size # size of cell in meters

## Functions

def latlng_to_geohash(lat, lng)
  return(gridcell_to_geohash(latlng_to_gridcell(lat, lng)))
end

def latlng_to_gridcell(lat, lng)
  # WGS84 (SRID 4326) -> Web Mercator (SRID 900913)
  x = (lng / 360.0) * Earth_circum
  y = Math::log(Math::tan((lat + 90) * (Math::PI / 360))) * Earth_radius
  # Move origin to bottom left corner
  x += (Earth_circum / 2)
  y += (Earth_circum / 2)
  # Convert to grid cell number
  xi = (x / Cell_size).floor
  yi = (y / Cell_size).floor
  return([xi, yi])
end

def gridcell_to_geohash(gridcell)
  # Convert to binary
  xb = gridcell[0].to_s(2).rjust(Zoom + 1, "0")
  yb = gridcell[1].to_s(2).rjust(Zoom + 1, "0")
  # Build hash
  return([xb.split(""), yb.split("")].transpose.join)
end

def geohash_to_latlng(geohash)
  # Expand hash to binary
  geochars = geohash.split("")
  xb = (0..geochars.length-2).step(2).map{ |i| geochars[i] }.join
  yb = (1..geochars.length-1).step(2).map{ |i| geochars[i] }.join
  # Convert to integer
  xi = xb.to_i(2)
  yi = yb.to_i(2)
  # Convert to meters
  x = xi * Cell_size
  y = yi * Cell_size
  # Move origin to center
  x -= (Earth_circum / 2)
  y -= (Earth_circum / 2)
  # Web Mercator (SRID 900913) -> WGS84 (SRID 4326)
  lng = x * (360.0 / Earth_circum)
  lat = 90 - (Math::atan2(1, Math::exp(y / Earth_radius)) * (360.0 / Math::PI))
  return([lat, lng])
end

def expand_geohash(geohash)
  n_chars = geohash.length
  lengths = (2..n_chars-2).step(2).reverse
  [geohash, lengths.collect{ |length| geohash[0,length] }].flatten
end

#################
## Load locations

# Retrieve data
creation_time = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%L")
locations = ActiveRecord::Base.connection.select_all('SELECT lat, lng, type_ids, muni FROM locations')
lat = locations.collect{ |x| x["lat"].to_f }
lng = locations.collect{ |x| x["lng"].to_f }
muni = locations.collect{ |x| x["muni"] == "t" }
type_ids = locations.collect{ |x| x["type_ids"].gsub(/[{}]/, "").split(",").collect{ |y| y.to_i } }

## Compute clusters

# Compute gridcells
gridcells = (0..lat.length-1).map{ |i| latlng_to_gridcell(lat[i], lng[i]) }

# Expand type_ids
n_types = type_ids.collect{ |x| x.length }
seq = 0..type_ids.length-1
lat = seq.map{ |i| [lat[i]] * n_types[i] }.flatten
lng = seq.map{ |i| [lng[i]] * n_types[i] }.flatten
muni = seq.map{ |i| [muni[i]] * n_types[i] }.flatten
gridcells = seq.map{ |i| [gridcells[i]] * n_types[i] }.flatten(1)
type_id = type_ids.flatten
# Combine variables
l = gridcells.zip(type_id, muni, lat, lng)

# Compute leaf nodes
groups = l.group_by{ |x| x[0, 3]}
lat = groups.values.collect{ |g| g.collect{ |l| l[3] }.sum.to_f / g.length }
lng = groups.values.collect{ |g| g.collect{ |l| l[4] }.sum.to_f / g.length }
counts = groups.values.collect{ |g| g.length }
# Compute geohashes
geohashes = groups.keys.collect{ |x| gridcell_to_geohash(x[0]) }

# Expand geohashes
geohashes = geohashes.map{ |geo| expand_geohash(geo) }
n_geohashes = geohashes.collect{ |x| x.length }
seq = 0..geohashes.length-1
type_id = groups.keys.collect{ |k| k[1] }
type_id = seq.map{ |i| [type_id[i]] * n_geohashes[i] }.flatten
muni = groups.keys.collect{ |k| k[2] }
muni = seq.map{ |i| [muni[i]] * n_geohashes[i] }.flatten
lat = seq.map{ |i| [lat[i]] * n_geohashes[i] }.flatten
lng = seq.map{ |i| [lng[i]] * n_geohashes[i] }.flatten
counts = seq.map{ |i| [counts[i]] * n_geohashes[i] }.flatten
# Combine variables
c = geohashes.flatten.zip(type_id, muni, lat, lng, counts)

# Compute parent nodes
groups = c.group_by{ |x| x[0, 3] }
lat = groups.values.collect{ |g| g.collect{ |x| x[3] * x[5] }.sum.to_f / g.collect{ |x| x[5] }.sum }
lng = groups.values.collect{ |g| g.collect{ |x| x[4] * x[5] }.sum.to_f / g.collect{ |x| x[5] }.sum }
counts = groups.values.collect{ |g| g.collect{ |x| x[5] }.sum }
# FIXME: Map zoom on Falling Fruit: z2 (grid level) = (z > 3) ? z + 1 : z
zoom = groups.keys.collect{ |k| (k[0].length / 2) - 1 }
clusters = groups.keys.collect{ |k| k[0]}.zip(groups.keys.collect{ |k| k[1]}, groups.keys.collect{ |k| k[2]}, lat, lng, counts, zoom)

}

# Update table
ActiveRecord::Base.connection.execute("DELETE FROM new_clusters;")
sql = "INSERT INTO new_clusters (geohash, type_id, muni, lat, lng, count, zoom, created_at, updated_at) VALUES #{clusters.collect{ |x| "('" + x[0] + "', " + x[1,6].join(", ") + ", '" + creation_time + "', '" + creation_time + "')" }.join(", ")}"
ActiveRecord::Base.connection.execute(sql)
