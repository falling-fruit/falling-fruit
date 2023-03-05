DATETIME = $(shell date +%Y%m%d%H%M%S)

bounce:
	sudo su - -c "R -e \"devtools::install_github('falling-fruit/fruitr')\""
	git pull
	bundle install
	bundle --deployment
	bundle exec rake db:migrate
	sudo chown -R www-data:www-data tmp
	sudo chmod -R 777 tmp
	bundle exec rake tmp:cache:clear
	bundle exec rake assets:precompile
	thin -C /etc/thin/fallingfruit.yaml restart

export:
	time bundle exec rake export:data
	rm -f public/locations.csv.bz2
	bzip2 public/locations.csv
	rm -f public/types.csv.bz2
	bzip2 public/types.csv

clusters:
	bundle exec rake make_clusters
