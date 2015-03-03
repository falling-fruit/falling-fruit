module ClusterStuff

  # assumes not muni increments the not muni clusters
  def cluster_increment(location,tids=nil)
    found = {}
    tids = location.accepted_type_ids if tids.nil?
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

  # assumes not muni, increments the not muni clusters
  def cluster_decrement(location,tids=nil)
    tids = location.accepted_type_ids if tids.nil?
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
