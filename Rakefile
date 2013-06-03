#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

FallingfruitWebapp::Application.load_tasks

task(:clear_cache => :environment) do
  LocationsController.new.expire_things
end

task(:geocode => :environment) do
  Geocoder.configure({:always_raise => :all})	
  n = Location.where("lat is null and lng is null").count
  Location.where("lat is null and lng is null").each{ |l|
    begin
      puts n
      l.geocode
      unless [l.lng,l.lat].any? { |e| e.nil? }
        l.location = "POINT(#{l.lng} #{l.lat})"
        l.save
        n -= 1
      end
      sleep 1
    rescue Geocoder::OverQueryLimitError => e
      puts e
      break
    end
  }
end

task(:export_data => :environment) do
   CSV.open("public/data.csv","wb") do |csv|
     cols = ["id","lat","lng","unverified","description","season_start","season_stop",
             "no_season","author","address","created_at","updated_at",
             "quality_rating","yield_rating","access","import_link","name"]
     csv << cols
       Location.joins("INNER JOIN locations_types ON locations_types.location_id=locations.id").
           joins("LEFT OUTER JOIN types ON locations_types.type_id=types.id").
           select('ARRAY_AGG(COALESCE(types.name,locations_types.type_other)) as name, locations.id as id, 
                   description, lat, lng, address, season_start, season_stop, no_season, access, unverified, 
                   yield_rating, quality_rating, author, import_id, locations.created_at, locations.updated_at').
           group("locations.id").each{ |l|
         l.import_link = l.import_id.nil? ? nil : "http://fallingfruit.org/imports/#{l.import_id}"
         csv << cols.collect{ |e| l[e] }
       }
   end
end
