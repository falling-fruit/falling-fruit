COPY (
SELECT l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop,
l.no_season, l.author, l.address, l.created_at, l.updated_at, l.quality_rating, l.yield_rating,
l.access, i.name as import_name, i.url as import_url, i.license as import_license,
string_agg(coalesce(lt.type_other,t.name),',') as name 
FROM locations l, imports i, locations_types lt left outer join types t on lt.type_id=t.id 
WHERE l.import_id=i.id AND lt.location_id=l.id
GROUP BY l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop,
l.no_season, l.address, l.created_at, l.updated_at, l.quality_rating,
l.yield_rating, l.access, i.name, i.url, i.license
UNION
SELECT l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop,
l.no_season, l.author, l.address, l.created_at, l.updated_at, l.quality_rating, l.yield_rating,
l.access, NULL as import_name, NULL as import_url, NULL as import_license,
string_agg(coalesce(lt.type_other,t.name),',') as name
FROM locations l, locations_types lt left outer join types t on lt.type_id=t.id
WHERE l.import_id IS NULL AND lt.location_id=l.id
GROUP BY l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop,
l.no_season, l.address, l.created_at, l.updated_at, l.quality_rating,
l.yield_rating, l.access
) TO '/tmp/ff.csv' CSV HEADER;
