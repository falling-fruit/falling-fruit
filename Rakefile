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
             csv << [l.id,l.lat,l.lng,l.unverified,l.description,l.season_start.nil? ? nil : Location::Months[l.season_start],
                     l.season_stop.nil? ? nil : Location::Months[l.season_stop],l.no_season,l.author,l.address,l.created_at,l.updated_at,
                     l.quality_rating.nil? ? nil : Location::Ratings[l.quality_rating],l.yield_rating.nil? ? nil : Location::Ratings[l.yield_rating],
                     l.access.nil? ? nil : Location::AccessShort[l.access],l.import_id.nil? ? nil : "http://fallingfruit.org/imports/#{l.import_id}",
                     l.name]
       }
   end
end

task(:import => :environment) do
   typehash = {}
   Type.all.each{ |t|
     typehash[t.name] = t
   }
   dh = Dir.open("public/import")
   dh.each{ |l|
     next unless l =~ /^(\d+).csv$/
     import_id = $1.to_i
     import = Import.find(import_id)
     next if import.nil?
     print "#{import_id}: "
     n = 0
     errs = []
     text_errs = []
     ok_count = 0
     CSV.foreach("public/import/#{l}") do |row|
       print "."
       n += 1
       next if n == 1 or row.join.blank?
       location = Location.build_from_csv(row,typehash)
       location.import = import
       location.client = 'import'
       if location.lat.nil? or location.lng.nil? and (!location.address.nil? and (!location.address.length == 0))
         location.geocode
       end
       if location.valid?
         ok_count += 1
         location.save
       else
         text_errs << location.errors
         errs << row
       end
     end
     c = Change.new
     c.description = "#{ok_count} new locations imported from #{import.name} (#{import.url})"
     c.save
     if errs.any?
       errFile ="public/import/#{import_id}_error.csv"
       errs.insert(0,Location.csv_header)
       errCSV = CSV.open(errFile,"wb") do |csv|
         errs.each {|row| csv << row}
       end
     end
     ApplicationController.cluster_batch_increment(import)
     FileUtils.mv "public/import/#{l}", "public/import/#{import_id}_done.csv"
     puts
   } 
   dh.close
end
