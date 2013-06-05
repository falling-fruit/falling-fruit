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
	pgsql2shp -u fallingfruit_user -h localhost -f cluster_boundaries.shp -g polygon fallingfruit_db 'SELECT * FROM clusters'
