DATETIME = $(shell date +%Y%m%d%H%M%S)

export:
	#cp export_csv.sql /tmp/
	#sudo su postgres -c "psql -f /tmp/export_csv.sql fallingfruit_db"
	#cp /tmp/ff.csv.bz2 public/data.csv.bz2
	time rake export_data
	rm -f public/data.csv.bz2
	bzip2 public/data.csv

clusters:
	rake db:migrate:redo VERSION=20130503191902

shapes:
	pgsql2shp -u fallingfruit_user -h localhost -f $(DATETIME)_cluster_polygon.shp fallingfruit_db 'SELECT zoom, muni, count, created_at, updated_at, ST_TRANSFORM(ST_SETSRID(polygon,900913),4326) FROM clusters ORDER BY zoom ASC, muni ASC'
		pgsql2shp -u fallingfruit_user -h localhost -f $(DATETIME)_cluster_point.shp fallingfruit_db 'SELECT zoom, muni, count, created_at, updated_at, ST_TRANSFORM(ST_SETSRID(cluster_point,900913),4326) FROM clusters ORDER BY zoom ASC, muni ASC'
	pgsql2shp -u fallingfruit_user -h localhost -f $(DATETIME)_grid_point.shp fallingfruit_db 'SELECT zoom, muni, count, created_at, updated_at, ST_TRANSFORM(ST_SETSRID(grid_point,900913),4326) FROM clusters ORDER BY zoom ASC, muni ASC'