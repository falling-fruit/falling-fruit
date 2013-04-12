export:
	#cp export_csv.sql /tmp/
	#sudo su postgres -c "psql -f /tmp/export_csv.sql fallingfruit_db"
	sudo mv /tmp/ff.csv public/data.csv
	sudo rm -f public/data.csv.bz2
	sudo bzip2 public/data.csv
