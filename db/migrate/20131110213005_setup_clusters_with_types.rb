class SetupClustersWithTypes < ActiveRecord::Migration

  def add_type_clusters(type)
    $stderr.puts "Type: #{type.id}"
    earth_radius = 6378137.0
    gsize_init = 2.0 * Math::PI * earth_radius
    xo = - gsize_init / 2.0
    yo = gsize_init / 2.0
    #type_ids = ([type.id] + type.all_children.collect{ |ct| ct.id }).flatten.uniq.compact
    type_ids = [type.id]

    (0..12).each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init / (2.0 ** z2)
      execute <<-SQL
        -- Without muni: DELETE
        DELETE FROM clusters
        WHERE method = 'grid' AND muni = 'f' AND zoom = #{z} AND type_id = #{type.id};
        -- Without muni: INSERT
        INSERT INTO clusters (method, muni, zoom, grid_size, count, cluster_point, grid_point, polygon, created_at, updated_at, type_id)
        SELECT
          'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
          st_setsrid(st_makebox2d(st_translate(grid_point, -#{gsize} / 2, -#{gsize} / 2),
          st_translate(grid_point, #{gsize} / 2, #{gsize} / 2)), 900913) as polygon,
          NOW() as created_at, NOW() as updated_at, #{type.id} as type_id
        FROM (
          SELECT
            count(location) as count,
            st_centroid(st_transform(st_collect(st_setsrid(location::geometry, 4326)), 900913)) as cluster_point,
            st_snaptogrid(st_transform(st_setsrid(location::geometry, 4326), 900913), #{xo} + #{gsize} / 2, #{yo} - #{gsize} / 2, #{gsize}, #{gsize}) as grid_point
          FROM locations
          WHERE
            lng IS NOT NULL AND lat IS NOT NULL AND (
              import_id IS NULL OR import_id IN (
                SELECT id FROM imports WHERE NOT muni
              )
            ) AND
            locations.type_ids && ARRAY[#{type_ids.join(',')}]
          GROUP BY grid_point
        ) AS subq;
        -- With muni: DELETE
        DELETE FROM clusters
        WHERE method = 'grid' AND muni = 't' AND zoom = #{z} AND type_id = #{type.id};
        -- With muni: INSERT
        INSERT INTO clusters (method, muni, zoom, grid_size, count, cluster_point, grid_point, polygon, created_at, updated_at, type_id)
        SELECT
          'grid' as method, 't' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
          st_setsrid(st_makebox2d(st_translate(grid_point, -#{gsize} / 2, -#{gsize} / 2),
          st_translate(grid_point, #{gsize} / 2, #{gsize} / 2)), 900913) as polygon,
          NOW() as created_at, NOW() as updated_at, #{type.id} as type_id
        FROM (
          SELECT
            count(location) as count,
            st_centroid(st_transform(st_collect(st_setsrid(location::geometry, 4326)), 900913)) as cluster_point,
            st_snaptogrid(st_transform(st_setsrid(location::geometry, 4326), 900913), #{xo} + #{gsize} / 2, #{yo} - #{gsize} / 2, #{gsize}, #{gsize}) as grid_point
          FROM locations
          WHERE
            lng IS NOT NULL AND lat IS NOT NULL AND (
              import_id IS NOT NULL AND import_id IN (
                SELECT id FROM imports WHERE muni
              )
            ) AND
            locations.type_ids && ARRAY[#{type_ids.join(',')}]
          GROUP BY grid_point
        ) AS subq;
      SQL
    }
  end

  def up
    $stderr.puts "All types!"
    earth_radius = 6378137.0
    gsize_init = 2.0 * Math::PI * earth_radius
    xo = - gsize_init / 2.0
    yo = gsize_init / 2.0

    # all types clusters
    (0..12).each{ |z|
      z2 = (z > 3) ? z + 1 : z
      gsize = gsize_init / (2.0 ** z2)
      execute <<-SQL
        -- Without muni: DELETE
        DELETE FROM clusters
        WHERE method = 'grid' AND muni = 'f' AND zoom = #{z} AND type_id IS NULL;
        -- Without muni: INSERT
        INSERT INTO clusters (method, muni, zoom, grid_size, count, cluster_point, grid_point, polygon, created_at, updated_at)
        SELECT
          'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
          st_setsrid(st_makebox2d(st_translate(grid_point, -#{gsize} / 2, -#{gsize} / 2),
          st_translate(grid_point, #{gsize} / 2, #{gsize} / 2)), 900913) as polygon,
          NOW() as created_at, NOW() as updated_at
        FROM (
          SELECT
            count(location) as count,
            st_centroid(st_transform(st_collect(st_setsrid(location::geometry, 4326)), 900913)) as cluster_point,
            st_snaptogrid(st_transform(st_setsrid(location::geometry, 4326), 900913), #{xo} + #{gsize} / 2, #{yo} - #{gsize} / 2, #{gsize}, #{gsize}) as grid_point
          FROM locations
          WHERE
            lng IS NOT NULL AND lat IS NOT NULL AND (
              import_id IS NULL OR import_id IN (
                SELECT id FROM imports WHERE NOT muni
              )
            )
          GROUP BY grid_point
        ) AS subq;
        -- With muni: DELETE
        DELETE FROM clusters
        WHERE method = 'grid' AND muni = 't' AND zoom = #{z} AND type_id IS NULL;
        -- With muni: INSERT
        INSERT INTO clusters (method, muni, zoom, grid_size, count, cluster_point, grid_point, polygon, created_at, updated_at)
        SELECT
         'grid' as method, 'f' as muni, #{z} as zoom, #{gsize} as grid_size, count, cluster_point, grid_point,
         st_setsrid(st_makebox2d(st_translate(grid_point, -#{gsize} / 2, -#{gsize} / 2),
         st_translate(grid_point, #{gsize} / 2, #{gsize} / 2)), 900913) as polygon,
         NOW() as created_at, NOW() as updated_at
        FROM (
         SELECT
           count(location) as count,
           st_centroid(st_transform(st_collect(st_setsrid(location::geometry, 4326)), 900913)) as cluster_point,
           st_snaptogrid(st_transform(st_setsrid(location::geometry, 4326), 900913), #{xo} + #{gsize} / 2, #{yo} - #{gsize} / 2, #{gsize}, #{gsize}) as grid_point
         FROM locations
         WHERE
           lng IS NOT NULL AND lat IS NOT NULL AND (
             import_id IS NOT NULL AND import_id IN (
               SELECT id FROM imports WHERE muni
             )
           )
         GROUP BY grid_point
        ) AS subq;
      SQL
    }

    # per-type clusters
    Type.where(id: 1).each{ |t| add_type_clusters(t) }
  end

  def down
    # NOTE: Leave in place to allow updating in place on db:migrate:redo
    # execute "TRUNCATE clusters;"
  end
end
