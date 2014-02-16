class SetupClustersWithTypes < ActiveRecord::Migration

  def add_type_clusters(type)
    $stderr.puts "Type: #{type.id}"
    earth_radius = 6378137.0
    gsize_init = 2.0*Math::PI*earth_radius
    xo = -gsize_init/2.0
    yo = gsize_init/2.0
    type_ids = ([type.id] + type.all_children.collect{ |ct| ct.id }).flatten.uniq.compact

    (0..12).each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init/(2.0**z2)
      execute <<-SQL
      
      INSERT INTO clusters (method,muni,zoom,grid_size,count,cluster_point,grid_point,polygon,created_at,updated_at,type_id) 
       SELECT 'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon, 
       NOW() as created_at, NOW() as updated_at, #{type.id} as type_id FROM
       (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations, locations_types WHERE lng IS NOT NULL and lat IS NOT NULL AND (import_id IS NULL OR
       import_id IN (SELECT id FROM imports WHERE NOT muni)) AND locations_types.location_id=locations.id AND 
       locations_types.type_id IN (#{type_ids.join(",")}) GROUP BY grid_point) AS subq;

      INSERT INTO clusters (method,muni,zoom,grid_size,count,cluster_point,grid_point,polygon,created_at,updated_at,type_id) 
       SELECT 'grid' as method, 't' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon, 
       NOW() as created_at, NOW() as updated_at, #{type.id} as type_id FROM
       (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations, locations_types WHERE lng IS NOT NULL and lat IS NOT NULL AND (import_id IS NOT NULL AND
       import_id IN (SELECT id FROM imports WHERE muni)) AND locations_types.location_id=locations.id AND
       locations_types.type_id IN (#{type_ids.join(",")}) GROUP BY grid_point) AS subq;
      SQL
    }
  end

  def up
    # per-type clusters
    Type.all.each{ |t| add_type_clusters(t) }

    $stderr.puts "All types!"

    # all types clusters
    earth_radius = 6378137.0
    gsize_init = 2.0*Math::PI*earth_radius
    xo = -gsize_init/2.0
    yo = gsize_init/2.0
    (0..12).each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init/(2.0**z2)
      execute <<-SQL
      
      INSERT INTO clusters (method,muni,zoom,grid_size,count,cluster_point,grid_point,polygon,created_at,updated_at) 
       SELECT 'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon, 
       NOW() as created_at, NOW() as updated_at FROM
       (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND (import_id IS NULL OR
       import_id IN (SELECT id FROM imports WHERE NOT muni)) GROUP BY grid_point) AS subq;

      INSERT INTO clusters (method,muni,zoom,grid_size,count,cluster_point,grid_point,polygon,created_at,updated_at) 
       SELECT 'grid' as method, 't' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
       st_setsrid(st_makebox2d(st_translate(grid_point,-#{gsize}/2,-#{gsize}/2), st_translate(grid_point,#{gsize}/2,#{gsize}/2)),900913) as polygon, 
       NOW() as created_at, NOW() as updated_at FROM
       (SELECT count(location) as count, st_centroid(st_transform(st_collect(st_setsrid(location::geometry,4326)),900913)) as cluster_point,
       st_snaptogrid(st_transform(st_setsrid(location::geometry,4326),900913),#{xo}+#{gsize}/2,#{yo}-#{gsize}/2,#{gsize},#{gsize}) as grid_point
       FROM locations WHERE lng IS NOT NULL and lat IS NOT NULL AND (import_id IS NOT NULL AND
       import_id IN (SELECT id FROM imports WHERE muni)) GROUP BY grid_point) AS subq;
      SQL
    }
  end

  def down
    execute "TRUNCATE clusters;"
  end
end
