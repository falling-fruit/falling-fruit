export:
	#cp export_csv.sql /tmp/
	#sudo su postgres -c "psql -f /tmp/export_csv.sql fallingfruit_db"
	cp /tmp/ff.csv.bz2 public/data.csv.bz2
