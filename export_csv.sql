COPY (select * from locations l, locations_types lt, types t, imports i WHERE l.id=lt.location_id AND lt.type_id=t.id AND i.id=l.import_id) TO '/tmp/ff.csv' CSV HEADER;
