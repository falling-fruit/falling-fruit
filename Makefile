export:
	#cp export_csv.sql /tmp/
	#sudo su postgres -c "psql -f /tmp/export_csv.sql fallingfruit_db"
	cp /tmp/ff.csv.bz2 public/data.csv.bz2

clusters:
	rake db:migrate:down VERSION=20130503191902
	rake db:migrate:up VERSION=20130503191902
