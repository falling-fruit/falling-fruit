class SetupClusters < ActiveRecord::Migration
  def up
    (1..15).each{ |z|
      gsize = 360/(12.0*(2.0**(z-3)))
      execute <<-SQL
      INSERT INTO clusters (method,muni,zoom,grid_size,count,center_lng,center_lat,grid_point,polygon,created_at,updated_at) 
       SELECT 'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, 
       count, st_x(center_point) as center_lng, st_y(center_point) as center_lat, grid_point as location,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2),
       st_translate(grid_point,#{gsize}/2,#{gsize}/2)),4326) as polygon, NOW() as created_at, NOW() as updated_at FROM
       (SELECT count(location) as count, ST_Centroid(ST_Collect(location::geometry)) as center_point,
        ST_SnapToGrid(location::geometry,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND (import_id IS NULL OR
       import_id IN (SELECT id FROM imports WHERE NOT muni)) GROUP BY grid_point) AS subq;
      INSERT INTO clusters (method,muni,zoom,grid_size,count,center_lng,center_lat,grid_point,polygon,created_at,updated_at) 
      SELECT 'grid' as method, 't' as muni, #{z} as zoom, #{gsize} as grid_size, count, st_x(center_point) as center_lng, 
       st_y(center_point) as center_lat, grid_point as location,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2),
       st_translate(grid_point,#{gsize}/2,#{gsize}/2)),4326) as polygon, NOW() as created_at, NOW() as updated_at FROM
       (SELECT count(location) as count, ST_Centroid(ST_Collect(location::geometry)) as center_point,
        ST_SnapToGrid(location::geometry,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND
       import_id IN (SELECT id FROM imports WHERE muni) GROUP BY grid_point) AS subq;
      SQL
    }
  end

  def down
    execute "TRUNCATE clusters;"
  end
end
