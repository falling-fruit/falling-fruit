#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

SendEmails = false

FallingfruitWebapp::Application.load_tasks

# Find duplicate I18n values (en)
task(:find_duplicate_locale_values => :environment) do
  require 'yaml'
  temp = YAML.load_file("config/locales/en.yml")
  f = flatten_hash(temp["en"])
  df = f.group_by { |k,v| v }.select { |k,v| v.size > 1 }
  df.each { |k,v|
    puts "=> " + k + "\n" + v.collect { |ind| ind[0] }.join("\n")
  }
end

# Helper function: Flatten hash, locale style
# http://stackoverflow.com/questions/9647997/converting-a-nested-hash-into-a-flat-hash
def flatten_hash(h, f = [], g = {})
  return g.update({f.join('.') => h}) unless h.is_a? Hash
  h.each { |k,r| flatten_hash(r, f + [k], g) }
  g
end

# Resend email confirmation to unconfirmed users
# http://www.cheynewallace.com/resend-devise-confirmation-emails-for-incomplete/
task(:resend_confirmation => :environment) do
  users = User.where('confirmation_token IS NOT NULL')
  users.each do |user|
    user.send_confirmation_instructions
  end
end

task(:clear_cache => :environment) do
  LocationsController.new.expire_things
end

# Replaces '' in atomic character columns with default, and removes (nil, '') values from array columns.
# (prints number and location of changes to console)
task(:replace_blanks => :environment) do
  Rails.application.eager_load!
  ActiveRecord::Base.descendants.reject{ |m| m.name.include? "ActiveRecord::" }.each{ |model|
   model.columns.each{ |column|
     unless column.array
       if [:text,:string].include? column.type
         blanks = model.where(column.name => '')
         if blanks.length > 0
           puts '[' + blanks.length.to_s + 'x] ' + model.name + '.' + column.name + ' => ' + column.default.to_s
           blanks.update_all(column.name => column.default)
         end
       end
     else
       if [:text,:string].include? column.type
         blanks = model.where("ARRAY_LENGTH(#{column.name},1) > 0 and (#{column.name}[1] IS NULL or #{column.name}[1]='')")
       else
         blanks = model.where("ARRAY_LENGTH(#{column.name},1) > 0 and #{column.name}[1] IS NULL")
       end
       if blanks.length > 0
         puts '[' + blanks.length.to_s + 'x] ' + model.name + '.' + column.name + " - [nil, '']"
         blanks.find_each do |object|
          object[column.name] = object[column.name].reject(&:blank?)
          object.save
         end
       end
     end
    }
  }
end

# Removes pending types with no locations
task(:delete_unused_pending_types => :environment) do
  Type.where("pending").each do |type|
    if type.locations.blank? and type.children.blank?
      type.destroy
      puts '[' + type.id.to_s + '] ' + type.en_name
    end
  end
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
  Geocoder.configure(:api_key => GOOGLE_GEOCODING_KEY)
  n = Location.where("lat is null and lng is null").count
  Location.where("lat is null and lng is null").limit(100000).each{ |l|
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

task(:reverse_geocode => :environment) do
  Geocoder.configure(:api_key => GOOGLE_GEOCODING_KEY)
  filters = (
    "lat is not null and lng is not null" +
    " and city is null and state is null and country is null and address is null" +
    " and array_length(type_ids, 1) > 0"
  )
  n = Location.where(filters).count
  puts n
  Location.where(filters).limit(100000).each{ |l|
    begin
      puts n
      l.reverse_geocode
      l.save
      n -= 1
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

  task(:apples => :environment) do
    of = File.open("apples.csv","w")
    of.puts "lon,lat,q,y,no"
    t = Type.where("en_name='Apple'").first
    Location.where("type_ids @> ARRAY[#{t.id}]").each{ |l|
      of.puts [l.lng,l.lat,l.mean_quality_rating,l.mean_yield_rating,l.observations.length].join(",")
    }
    of.close
  end

  task(:data => :environment) do
    puts "Exporting Locations..."
    # r = ActiveRecord::Base.connection.execute("
    #   SELECT id, array_to_string(type_ids,', ') as type_ids, lat, lng, unverified,
    #   description, season_start, season_stop, no_season, author, address,
    #   created_at, updated_at, access, import_id,
    #   array_to_string(original_ids,', ') as original_ids
    #   FROM locations
    #   ORDER BY id
    # ")
    CSV.open("public/locations.csv", "wb") do |csv|
      csv << [
        "id", "type_ids", "lat", "lng", "unverified", "description",
        "season_start","season_stop", "no_season", "author", "address",
        "created_at", "updated_at", "access", "import_link", "original_ids",
        "hidden"
      ]
      Location.find_each() do |l|
        csv << [
          l.id,
          l.type_ids.nil? ? nil : l.type_ids.join(", "),
          l.lat, l.lng, l.unverified, l.description,
          l.season_start.nil? ? nil : I18n.t("date.month_names")[l.season_start.to_i + 1],
          l.season_stop.nil? ? nil : I18n.t("date.month_names")[l.season_stop.to_i + 1],
          l.no_season, l.author, l.address, l.created_at, l.updated_at,
          l.access.nil? ? nil : I18n.t("locations.infowindow.access_short")[l.access.to_i],
          l.import_id.nil? ? nil : "https://fallingfruit.org/imports/#{l.import_id}",
          l.original_ids.nil? ? nil : l.original_ids.join(", "),
          l.hidden
        ]
      end
      # r.each{ |row|
      #   csv << [
      #     row["id"], row["type_ids"], row["lat"], row["lng"], row["unverified"],
      #     row["description"],
      #     row["season_start"].nil? ? nil : I18n.t("date.month_names")[row["season_start"].to_i + 1],
      #     row["season_stop"].nil? ? nil : I18n.t("date.month_names")[row["season_stop"].to_i + 1],
      #     row["no_season"], row["author"], row["address"], row["created_at"], row["updated_at"],
      #     row["access"].nil? ? nil : I18n.t("locations.infowindow.access_short")[row["access"].to_i],
      #     row["import_id"].nil? ? nil : "https://fallingfruit.org/imports/#{row["import_id"]}",
      #     row["original_ids"]
      #   ]
      # }
    end
    puts "Exporting Types..."
    CSV.open("public/types.csv","wb") do |csv|
      csv << [
        "id", "parent_id", "scientific_name", "scientific_synonyms", "taxonomic_rank",
        "en_name", "en_synonyms", "en_wikipedia_url",
        "de_name", "el_name", "es_name", "fr_name", "he_name", "it_name",
        "pl_name", "pt_br_name", "sv_name",
        "category_mask", "pending",
      ]
      Type.find_each() do |t|
        csv << [
          t.id, t.parent_id, t.scientific_name, t.scientific_synonyms,
          t.taxonomic_rank.nil? ? nil : Type::Ranks[t.taxonomic_rank],
          t.en_name, t.en_synonyms, t.wikipedia_url,
          t.de_name, t.el_name, t.es_name, t.fr_name, t.he_name, t.it_name,
          t.pl_name, t.pt_br_name, t.sv_name,
          mask_to_array(t.category_mask, Type::Categories).join(", "),
          t.pending
        ]
      end
    end
  end

  task(:type_template => :environment) do
    CSV.open("public/type_template.csv","wb") do |csv|
      cols = ["ID","English Common Name","Latin Name","Wikipedia Link"]
      csv << cols
      Type.all.each do |t|
        csv << [t.id,t.en_name,t.scientific_name,t.wikipedia_url]
      end
    end
  end

end

task(:import_type_translations => :environment) do
  I18n.available_locales.each do |l|
    next unless File.exists? "util/#{l}_names.csv"
    n = 0
    id_col = nil
    trans_cols = []
    puts l
    dbl = l.to_s.downcase.gsub("-", "_")
    CSV.foreach("util/#{l}_names.csv") do |row|
      if n == 0
        row.each_with_index do |d,i|
          if d =~ /ff_id/
            id_col = i
          elsif d =~ /translated_name/
            trans_cols.push i
          end
        end
      else
        id = row[id_col].to_i
        trans = trans_cols.collect{ |i| row[i] }.compact.first
        trans = trans.split(/,/).first unless trans.nil? or trans.index(",").nil?
        begin
          t = Type.find(id)
          if t["#{dbl}_name"].nil? and not trans.nil?
            t["#{dbl}_name"] = trans
            t.save
            print "[#{id}]"
          else
            print "_"
          end
        rescue
          $stderr.print "?"
        end
      end
      n += 1
    end
    puts
  end
end

task(:import => :environment) do
  Geocoder.configure(:api_key => GOOGLE_GEOCODING_KEY)
  # Check for lockfile
  if File.exists? "public/import/lockfile"
    puts "Lockfile exists, not running!"
    exit
  end
  # Delete unused pending types
  Rake::Task["delete_unused_pending_types"].invoke
  # Check for duplicate types
  names = Type.all.collect{ |t| t.full_name }
  if not names.detect{ |name| names.rindex(name) != names.index(name) }.nil?
    puts "Duplicate types detected, not running!"
    puts names.select{ |name| names.count(name) > 1 }.uniq
    exit
  end
  FileUtils.touch "public/import/lockfile"
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
    done = []
    errsFile = "public/import/#{import_id}_error.csv"
    if File.exist?(errsFile)
      csvfile = errsFile
    else
      csvfile = "public/import/#{import_id}.csv"
    end
    CSV.foreach(csvfile) do |row|
      n += 1
      next if n == 1 or row.join.blank?
      print "."
      location = Location.build_from_csv(row, import.default_category_mask)
      location.import = import
      location.client = 'import'
      location.muni = import.muni
      if (location.lat.nil? or location.lng.nil?) and !location.address.blank?
        print "G"
        location.geocode
      end
      if location.type_ids.length > 0 and location.valid? and location.save
        print "S"
        if import.auto_cluster == true
          print "C"
          cluster_increment(location)
        end
        done << row
      else
        errs << row
      end
    end
    doneFile = "public/import/#{import_id}_done.csv"
    if done.any?
      unless File.exist?(doneFile)
        done.insert(0, Location.csv_header)
      end
      doneCSV = CSV.open(doneFile, "ab+") do |csv|
        done.each{ |row| csv << row }
      end
      if import.auto_cluster != true
        print "\nRebuilding all clusters..."
        Rake::Task["make_clusters"].execute
      end
    end
    if errs.any?
      errs.insert(0, Location.csv_header)
      errsCSV = CSV.open(errsFile, "wb") do |csv|
        errs.each{ |row| csv << row }
      end
    else
      FileUtils.rm_f errsFile
      FileUtils.rm_f "public/import/#{l}"
    end
    puts
  }
  dh.close
  FileUtils.rm_f "public/import/lockfile"
end

task(:make_clusters => :environment) do
  file = Rails.root.join("util", "make_clusters.R")
  postgres_exists = `if id postgres >/dev/null 2>&1; then
    echo "true"
  else
    echo "false"
  fi`
  if postgres_exists == "false\n"
    `Rscript --vanilla #{file}`
  else
    `sudo su postgres -c "Rscript --vanilla #{file} fallingfruit_user"`
  end
end

namespace :db do
  task :patch_adapter do
    require './config/initializers/postgresql_adapter'
  end
  task :create => :patch_adapter
  task :drop => :patch_adapter
end

task :pg_dump do
  env = ENV['RAILS_ENV'] || 'development'
  db = YAML::load(File.open('config/database.yml'))[env]
  `pg_dump --dbname=#{db['database']} --host=#{db['host']} --port=#{db['port']} --username=#{db['username']} --no-owner --schema-only > db/schema.sql`
  `pg_dump --dbname=#{db['database']} --host=#{db['host']} --port=#{db['port']} --username=#{db['username']} --no-owner --data-only --table=schema_migrations >> db/schema.sql`
end

task :pg_load do
  env = ENV['RAILS_ENV'] || 'development'
  db = YAML::load(File.open('config/database.yml'))[env]
  `psql #{db['database']} --host=#{db['host']} --port=#{db['port']} --username=#{db['username']} < db/schema.sql`
end
