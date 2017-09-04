module ClusterStuff

  # ---- Constants ----

  Earth_radius = 6378137 # meters
  Earth_circumference = 2 * Math::PI * Earth_radius
  Max_grid_zoom = 13 # 12 (map) + 1 (denser clusters)

  # ---- Helper functions ----

  # WGS84 (SRID 4326) <-> Web Mercator (SRID 900913)

  def lnglat_to_xy(lnglat)
    x = (lnglat[0] / 360.0) * Earth_circumference
    y = Math::log(Math::tan((lnglat[1] + 90) * (Math::PI / 360))) * Earth_radius
    [x, y]
  end

  def xy_to_lnglat(xy)
    lng = xy[0] * (360.0 / Earth_circumference)
    lat = 90 - (Math::atan2(1, Math::exp(xy[1] / Earth_radius)) * (360.0 / Math::PI))
    [lng, lat]
  end

  # Web Mercator (SRID 900913) <-> Grid cell indices
  # NOTE: Conversion from grid cell indices returns lower left corner of cell.

  def xy_to_gridcell(xy, zoom)
    # Move origin to bottom left corner
    x = xy[0] + Earth_circumference / 2
    y = xy[1] + Earth_circumference / 2
    # Convert to grid cell number
    cell_size = Earth_circumference / (2 ** zoom)
    xi = (x / cell_size).floor
    yi = (y / cell_size).floor
    [xi, yi, zoom]
  end

  def gridcell_to_xy(xyz)
    cell_size = Earth_circumference / (2 ** xyz[2])
    x = xyz[0] * cell_size
    y = xyz[1] * cell_size
    # Move origin to center
    x -= Earth_circumference / 2
    y -= Earth_circumference / 2
    [x, y]
  end

  # Grid cell indices <-> Geohash

  def gridcell_to_geohash(xyz)
    # Convert to binary
    xb = xyz[0].to_s(2).rjust(xyz[2] + 1, "0")
    yb = xyz[1].to_s(2).rjust(xyz[2] + 1, "0")
    # Build hash
    [xb.split(""), yb.split("")].transpose.join
  end

  def geohash_to_gridcell(geohash)
    # Expand hash to binary
    geochars = geohash.split("")
    xb = (0..geochars.length-2).step(2).map{ |i| geochars[i] }.join
    yb = (1..geochars.length-1).step(2).map{ |i| geochars[i] }.join
    # Convert to integer
    xi = xb.to_i(2)
    yi = yb.to_i(2)
    zoom = (geohash.length / 2) - 1
    [xi, yi, zoom]
  end

  def expand_geohash(geohash)
    n_chars = geohash.length
    lengths = (2..n_chars-2).step(2).reverse
    [geohash, lengths.collect{ |length| geohash[0,length] }].flatten
  end

  def geohash_to_zoom(geohash)
    (geohash.length / 2) - 1
  end

  # Cluster centers

  def weighted_mean(values, weights)
    values.zip(weights).map{ |v, w| v.to_f * w.to_f }.sum / weights.sum
  end

  def move_xy(start_xy, start_count, xy, count)
    new_x = weighted_mean([start_xy[0], xy[0]], [start_count, count])
    new_y = weighted_mean([start_xy[1], xy[1]], [start_count, count])
    [new_x, new_y]
  end

  # ---- Add location ----

  def cluster_increment(location, type_ids = nil)
    type_ids = location.type_ids if type_ids.nil?
    # Convert lng, lat to geohash
    lnglat = [location.lng, location.lat]
    xy = lnglat_to_xy(lnglat)
    gridcell = xy_to_gridcell(xy, zoom = Max_grid_zoom)
    geohash = gridcell_to_geohash(gridcell)
    # Expand geohash
    geohashes = expand_geohash(geohash)
    # Existing clusters:
    @clusters = Cluster.where({muni: location.muni, type_id: type_ids, geohash: geohashes})
    @clusters.each{ |c|
      new_xy = move_xy([c.x, c.y], c.count, xy, 1)
      c.x = new_xy[0]
      c.y = new_xy[1]
      c.count += 1
      c.save
    }
    # Missing clusters:
    all_combos = geohashes.product(type_ids)
    existing_combos = @clusters.collect{ |c| [c.geohash, c.type_id] }
    missing_combos = all_combos - existing_combos
    missing_combos.each{ |geohash, type_id|
      c = Cluster.new
      c.geohash = geohash
      c.zoom = geohash_to_zoom(geohash)
      c.type_id = type_id
      c.muni = location.muni
      c.x = xy[0]
      c.y = xy[1]
      c.count = 1
      c.save
    }
  end
  module_function :cluster_increment

  # ---- Remove location ----

  def cluster_decrement(location, type_ids = nil)
    type_ids = location.type_ids if type_ids.nil?
    # Convert lng, lat to geohash
    lnglat = [location.lng, location.lat]
    xy = lnglat_to_xy(lnglat)
    gridcell = xy_to_gridcell(xy, zoom = Max_grid_zoom)
    geohash = gridcell_to_geohash(gridcell)
    # Expand geohash
    geohashes = expand_geohash(geohash)
    # Existing clusters:
    @clusters = Cluster.where({muni: location.muni, type_id: type_ids, geohash: geohashes})
    @clusters.each{ |c|
      if c.count <= 1
        c.destroy
      else
        # Move mean coordinates
        new_xy = move_xy([c.x, c.y], c.count, xy, -1)
        c.x = new_xy[0]
        c.y = new_xy[1]
        c.count -= 1
        c.save
      end
    }
  end
  module_function :cluster_decrement

end
