class ApplicationController < ActionController::Base
  protect_from_forgery

  private

  before_filter :instantiate_controller_and_action_names
 
  def instantiate_controller_and_action_names
      @current_action = action_name
      @current_controller = controller_name
  end

  before_filter :set_current_user

  def set_current_user
    User.current_user = current_user
  end

  # catch all perms errors and punt to root
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
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

  def prepare_for_mobile
    session[:mobile_param] = params[:mobile] if params[:mobile].present? and params[:mobile]
    request.format = :mobile if mobile_device?
  end

  # assumes not muni, increments the not muni clusters
  def self.cluster_increment(location)
    found = {}
    tids = location.locations_types.collect{ |lt| lt.type_id }.compact
    ml = Location.select("ST_X(ST_TRANSFORM(location::geometry,900913)) as x, ST_Y(ST_TRANSFORM(location::geometry,900913)) as y").where("id=#{location.id}").first
    Cluster.select("ST_X(cluster_point) as x, ST_Y(cluster_point) as y, count, *").where("ST_INTERSECTS(ST_TRANSFORM(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),900913),polygon) AND muni = 'f' AND (type_id IS NULL or type_id IN (#{tids.join(",")}))").each{ |clust|
    
      # since the cluster center is the arithmetic mean of the bag of points, simply integrate this points' location proportionally
      # e.g., https://en.wikipedia.org/wiki/Moving_average#Cumulative_moving_average
      clust.count += 1
      newx = clust.x.to_f+((ml.x.to_f-clust.x.to_f)/clust.count.to_f)
      newy = clust.y.to_f+((ml.y.to_f-clust.y.to_f)/clust.count.to_f)
      clust.cluster_point = "POINT(#{newx} #{newy})"
      clust.save

      found[clust.type_id] = [] if found[clust.type_id].nil?
      found[clust.type_id] << clust.zoom
    }
    found.each{ |type_id,found_by_type|
      cluster_seed(location,(0..12).to_a - found_by_type,false,type_id) unless found_by_type.max == 12
    }
  end
  helper_method :cluster_increment

  # assumes not muni, increments the not muni clusters
  def self.cluster_decrement(location)
    tids = location.locations_types.collect{ |lt| lt.type_id }.compact
    ml = Location.select("ST_X(ST_TRANSFORM(location::geometry,900913)) as x, ST_Y(ST_TRANSFORM(location::geometry,900913)) as y").where("id=#{location.id}").first
    Cluster.select("ST_X(cluster_point) as x, ST_Y(cluster_point) as y, count, *").where("ST_INTERSECTS(ST_TRANSFORM(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),900913),polygon) AND muni = 'f' AND (type_id IS NULL or type_id IN (#{tids.join(",")}))").each{ |clust|
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

  def self.cluster_batch_increment(import)
    earth_radius = 6378137.0
    gsize_init = 2.0*Math::PI*earth_radius
    xo = -gsize_init/2.0
    yo = gsize_init/2.0
    (0..12).each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init/(2.0**z2)
      r = ActiveRecord::Base.connection.execute <<-SQL
      SELECT count, cluster_point, grid_point, ST_X(cluster_point) AS x, ST_Y(cluster_point) AS y,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon
       FROM
       (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND import_id=#{import.id} GROUP BY grid_point) AS subq
      SQL
      r.each{ |row|
        c = Cluster.select("ST_X(cluster_point) AS cx, ST_Y(cluster_point) as cy, *").
                    where("method = ? AND muni = ? AND zoom = ? and grid_point = ?",'grid',import.muni,z,row["grid_point"]).first
        if c.nil?
          c = Cluster.new
          c.method = 'grid'
          c.count = row["count"]
          c.cluster_point = row["cluster_point"]
          c.grid_point = row["grid_point"]
          c.zoom = z
          c.grid_size = gsize
          c.polygon = row["polygon"]
          c.muni = import.muni
          c.save
        else
          c.count = row["count"].to_i + c.count.to_i
          newx = c.cx.to_f+((row["x"].to_f-c.cx.to_f)/c.count.to_f)
          newy = c.cy.to_f+((row["y"].to_f-c.cy.to_f)/c.count.to_f)
          c.cluster_point = "POINT(#{newx} #{newy})"
          c.save
        end
      }  
      # Then again for each type
      Type.all.each{ |type|
        r = ActiveRecord::Base.connection.execute <<-SQL
        SELECT count, cluster_point, grid_point, ST_X(cluster_point) AS x, ST_Y(cluster_point) AS y,
         st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon
         FROM
         (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
         st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
         FROM locations, locations_types WHERE lng IS NOT NULL and lat IS NOT NULL AND import_id=#{import.id} 
         AND locations.id=locations_types.location_id AND locations_types.type_id=#{type.id} GROUP BY grid_point) AS subq
        SQL
        r.each{ |row|
          c = Cluster.select("ST_X(cluster_point) AS cx, ST_Y(cluster_point) as cy, *").
                      where("method = ? AND muni = ? AND zoom = ? and grid_point = ? AND type_id = ?",
                            'grid',import.muni,z,row["grid_point"],type.id).first
          if c.nil?
            c = Cluster.new
            c.method = 'grid'
            c.count = row["count"]
            c.cluster_point = row["cluster_point"]
            c.grid_point = row["grid_point"]
            c.zoom = z
            c.grid_size = gsize
            c.polygon = row["polygon"]
            c.muni = import.muni
            c.save
          else
            c.count = row["count"].to_i + c.count.to_i
            newx = c.cx.to_f+((row["x"].to_f-c.cx.to_f)/c.count.to_f)
            newy = c.cy.to_f+((row["y"].to_f-c.cy.to_f)/c.count.to_f)
            c.cluster_point = "POINT(#{newx} #{newy})"
            c.save
          end
        }  
      }
    }
  end
  helper_method :cluster_batch_increment

  def self.cluster_batch_decrement(import)
    earth_radius = 6378137.0
    gsize_init = 2.0*Math::PI*earth_radius
    xo = -gsize_init/2.0
    yo = gsize_init/2.0
    (0..12).each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init/(2.0**z2)
      r = ActiveRecord::Base.connection.execute <<-SQL
      SELECT count, cluster_point, grid_point, ST_X(cluster_point) AS x, ST_Y(cluster_point) AS y,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon
       FROM
       (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND import_id=#{import.id} GROUP BY grid_point) AS subq
      SQL
      r.each{ |row|
        c = Cluster.select("ST_X(cluster_point) AS cx, ST_Y(cluster_point) as cy, *").
                    where("method = ? AND muni = ? AND zoom = ? and grid_point = ?",'grid',import.muni,z,row["grid_point"]).first
        unless c.nil?
          c.count = c.count.to_i - row["count"].to_i
          if (c.count <= 0)
            c.destroy
          else
            newx = c.cx.to_f+((row["x"].to_f-c.cx.to_f)/c.count.to_f)
            newy = c.cy.to_f+((row["y"].to_f-c.cy.to_f)/c.count.to_f)
            c.cluster_point = "POINT(#{newx} #{newy})"
            c.save
          end
        end
      }  
      # Then again for each type
      Type.all.each{ |type|
        r = ActiveRecord::Base.connection.execute <<-SQL
        SELECT count, cluster_point, grid_point, ST_X(cluster_point) AS x, ST_Y(cluster_point) AS y,
         st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon
         FROM
         (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
         st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
         FROM locations, locations_types WHERE lng IS NOT NULL and lat IS NOT NULL AND import_id=#{import.id} 
         AND locations_types.location_id=locations.id AND locations_types.type_id=#{type.id} GROUP BY grid_point) AS subq
        SQL
        r.each{ |row|
          c = Cluster.select("ST_X(cluster_point) AS cx, ST_Y(cluster_point) as cy, *").
                      where("method = ? AND muni = ? AND zoom = ? and grid_point = ? and type_id = ?",
                            'grid',import.muni,z,row["grid_point"],type.id).first
          unless c.nil?
            c.count = c.count.to_i - row["count"].to_i
            if (c.count <= 0)
              c.destroy
            else
              newx = c.cx.to_f+((row["x"].to_f-c.cx.to_f)/c.count.to_f)
              newy = c.cy.to_f+((row["y"].to_f-c.cy.to_f)/c.count.to_f)
              c.cluster_point = "POINT(#{newx} #{newy})"
              c.save
            end
          end
        }  
      }
    }
  end
  helper_method :cluster_batch_decrement

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

  def log_changes(location,description)
    c = Change.new
    c.location = location
    c.description = description
    c.remote_ip = request.remote_ip
    c.user = current_user if user_signed_in?
    c.save
  end
  helper_method :log_changes

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


end
