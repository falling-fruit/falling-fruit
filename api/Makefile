start:
	pm2 start app.js -i 0

reload:
	pm2 reload app

stop:
	pm2 stop app

bench_prep:
	psql -U fallingfruit_user -h localhost -c "COPY (select lat, lng from locations order by random() limit 10) to stdout with csv header;" fallingfruit_new_db > coordinates.csv

bench:
	ruby benchmark.rb locations coordinates.csv > locations_benchmark.tsv
	ruby benchmark.rb clusters coordinates.csv > clusters_benchmark.tsv
