class SetupClusters < ActiveRecord::Migration
  def up
    earth_radius = 6378137
    gsize_init = 2*Math::PI*earth_radius
    xo = -gsize_init/2
    yo = gsize_init/2
    (0..12).each{ |z|
      gsize = gsize_init/(2.0**(z+1))
      execute <<-SQL
      
      INSERT INTO clusters (method,muni,zoom,grid_size,count,center_lng,center_lat,grid_point,polygon,created_at,updated_at) 
       SELECT 'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, 
       count, st_x(center_point) as center_lng, st_y(center_point) as center_lat, 
       st_transform(st_setsrid(grid_point,900913),4326) as grid_point,
       st_transform(st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2),
       st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913),4326) as polygon, NOW() as created_at, NOW() as updated_at FROM
       (SELECT count(location) as count, st_centroid(st_collect(location::geometry)) as center_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND (import_id IS NULL OR
       import_id IN (SELECT id FROM imports WHERE NOT muni)) GROUP BY grid_point) AS subq;
      
      INSERT INTO clusters (method,muni,zoom,grid_size,count,center_lng,center_lat,grid_point,polygon,created_at,updated_at) 
       SELECT 'grid' as method, 't' as muni, #{z} as zoom, #{gsize} as grid_size, count, 
       st_x(center_point) as center_lng, st_y(center_point) as center_lat, 
       st_transform(st_setsrid(grid_point,900913),4326) as grid_point,
       st_transform(st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2),
       st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913),4326) as polygon, NOW() as created_at, NOW() as updated_at FROM
       (SELECT count(location) as count, st_centroid(st_collect(location::geometry)) as center_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND
       import_id IN (SELECT id FROM imports WHERE muni) GROUP BY grid_point) AS subq;
      SQL
    }
  end

  def down
    execute "TRUNCATE clusters;"
  end
end