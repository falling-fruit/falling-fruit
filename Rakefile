#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

SendEmails = true

FallingfruitWebapp::Application.load_tasks

task(:clear_cache => :environment) do
  LocationsController.new.expire_things
end

task(:fix_ratings => :environment) do
  missing_count = 0
  copy_fail_count = 0
  File.open("util/ratings.txt","r"){ |fh|
    fh.each_line{ |l|
      id,qr,yr = l.strip.split(/\s+/)
      qr = nil if qr =~ /\\N/
      yr = nil if yr =~ /\\N/
      next if qr.nil? and yr.nil?
      puts "+ #{qr} #{yr}"
      begin
        l = Location.find(id)
      rescue ActiveRecord::RecordNotFound
        puts "deleted"
        next
      end
      if l.observations.empty?
        o = Observation.new
        o.quality_rating = qr.to_i
        o.yield_rating = qr.to_i
        o.observed_on = l.created_at.to_date
        o.location = l
        o.save
        missing_count += 1
      else
        o = l.observations.first
        o.quality_rating = qr.to_i if o.quality_rating.nil?
        o.yield_rating = yr.to_i if o.yield_rating.nil?
        o.save
        copy_fail_count += 1
      end
    }
  }
  puts "#{missing_count} missing, #{copy_fail_count} blank"
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

task(:range_changes => :environment) do
  sent_okay = 0
  User.where('range_updates_email AND range IS NOT NULL').each{ |u|
    m = Spammer.range_changes(u,7)
    next if m.nil?
    if SendEmails 
      begin
        m.deliver
      rescue
        $stderr.puts "Problem sending message!!! #{m}"
        next
      end
      sent_okay += 1
    else
      puts m
    end
  } 
  $stderr.puts "Sent #{sent_okay} messages successfully"
end

namespace :export do

  task(:data => :environment) do
     r = ActiveRecord::Base.connection.execute("SELECT ARRAY_AGG(COALESCE(types.name,locations_types.type_other)) as name, locations.id as id,
         description, lat, lng, address, season_start, season_stop, no_season, access, unverified, author, import_id,
         locations.created_at, locations.updated_at FROM locations
         INNER JOIN locations_types ON locations_types.location_id=locations.id LEFT OUTER
         JOIN types ON locations_types.type_id=types.id GROUP BY locations.id")
     CSV.open("public/data.csv","wb") do |csv|
       cols = ["id","lat","lng","unverified","description","season_start","season_stop",
               "no_season","author","address","created_at","updated_at",
               "quality_rating","yield_rating","access","import_link","muni","name"]
       csv << cols
       r.each{ |row|

         quality_rating = Location.find(row["id"]).mean_quality_rating
         yield_rating = Location.find(row["id"]).mean_yield_rating

         csv << [row["id"],row["lat"],row["lng"],row["unverified"],row["description"],
                 row["season_start"].nil? ? nil : Location::Months[row["season_start"].to_i],
                 row["season_stop"].nil? ? nil : Location::Months[row["season_stop"].to_i],
                 row["no_season"],row["author"],
                 row["address"],row["created_at"],row["updated_at"],
                 quality_rating.nil? ? nil : Location::Ratings[quality_rating],
                 yield_rating.nil? ? nil : Location::Ratings[yield_rating],
                 row["access"].nil? ? nil : Location::AccessShort[row["access"].to_i],
                 row["import_id"].nil? ? nil : "http://fallingfruit.org/imports/#{row["import_id"]}",
                 row["import_id"].nil? ? 'f' : (Import.find(row["import_id"]).muni ? 't' : 'f'),
                 row["name"]]
         }
     end
  end

  task(:types => :environment) do
    CSV.open("public/types.csv","wb") do |csv|
      cols = ["ID","English Common Name","Latin Name","Wikipedia Link","Translated Name"]
      csv << cols
      Type.all.each do |t|
        csv << [t.id,t.name,t.scientific_name,t.wikipedia_url]
      end
    end
  end

end

task(:import => :environment) do
   if File.exists? "public/import/lockfile"
     puts "Lockfile exists, not running"
     exit
   end 
   FileUtils.touch "public/import/lockfile"
   typehash = {}
   Type.all.each{ |t|
     typehash[t.name] = t
   }
   dh = Dir.open("public/import")
   dh.each{ |l|
     next unless l =~ /^(\d+).csv$/
     import_id = $1.to_i
     begin
       import = Import.find(import_id)
     rescue ActiveRecord::RecordNotFound => e
       next
     end
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
         location.save and ApplicationController.cluster_increment(location)
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
     FileUtils.mv "public/import/#{l}", "public/import/#{import_id}_done.csv"
     puts
   } 
   dh.close
   FileUtils.rm_f "public/import/lockfile"
end
