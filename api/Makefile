start:
	pm2 start app.js -i 0

reload:
	pm2 reload app

stop:
	pm2 stop app

bench_prep:
	psql -U fallingfruit_user -h localhost -c "COPY (select params from api_logs where endpoint='api/locations/cluster' ORDER BY RANDOM() limit 10000) to STDOUT with csv header;" fallingfruit_new_db > cluster_params.csv
	psql -U fallingfruit_user -h localhost -c "COPY (select params from api_logs where endpoint='api/locations/markers' ORDER BY RANDOM() limit 10000) to STDOUT with csv header;" fallingfruit_new_db > location_params.csv

bench:
	ruby benchmark.rb cluster cluster_params.csv > cluster_benchmark.txt
	ruby benchmark.rb location location_params.csv > location_benchmark.txt
