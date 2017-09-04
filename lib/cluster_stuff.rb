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

  def new_cluster_increment(location, type_ids = nil)
    type_ids = location.type_ids if type_ids.nil?
    # Convert lng, lat to geohash
    lnglat = [location.lng, location.lat]
    xy = lnglat_to_xy(lnglat)
    gridcell = xy_to_gridcell(xy, zoom = Max_grid_zoom)
    geohash = gridcell_to_geohash(gridcell)
    # Expand geohash
    geohashes = expand_geohash(geohash)
    # Existing clusters:
    @clusters = NewCluster.where({muni: location.muni, type_id: type_ids, geohash: geohashes})
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
      c = NewCluster.new
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
  module_function :new_cluster_increment

  # assumes not muni increments the not muni clusters
  def cluster_increment(location, tids = nil)
    found = {}
    tids = location.type_ids if tids.nil?
    muni = (location.import.nil? or (not location.import.muni)) ? false : true
    ml = Location.select("ST_X(ST_TRANSFORM(location::geometry,900913)) as xp, ST_Y(ST_TRANSFORM(location::geometry,900913)) as yp").where("id=?",location.id).first
    ts = (tids.nil? or tids.empty?) ? "" : " OR type_id IN (#{tids.join(",")})"
    Cluster.select("ST_X(cluster_point) as xp, ST_Y(cluster_point) as yp, count, *").where("ST_INTERSECTS(ST_TRANSFORM(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),900913),polygon) AND muni = ? AND (type_id IS NULL#{ts})",muni).each{ |clust|

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
  module_function :cluster_increment

  # ---- Remove location ----

  def new_cluster_decrement(location, type_ids = nil)
    type_ids = location.type_ids if type_ids.nil?
    # Convert lng, lat to geohash
    lnglat = [location.lng, location.lat]
    xy = lnglat_to_xy(lnglat)
    gridcell = xy_to_gridcell(xy, zoom = Max_grid_zoom)
    geohash = gridcell_to_geohash(gridcell)
    # Expand geohash
    geohashes = expand_geohash(geohash)
    # Existing clusters:
    @clusters = NewCluster.where({muni: location.muni, type_id: type_ids, geohash: geohashes})
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
  module_function :new_cluster_decrement

  # assumes not muni, increments the not muni clusters
  def cluster_decrement(location,tids=nil)
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
  module_function :cluster_decrement

  def cluster_seed(location,zooms,muni,type_id)
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
  module_function :cluster_seed

end
