#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

SendEmails = true

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

# Removes types with no locations
task(:delete_unused_pending_types => :environment) do
  Type.where("pending").each do |type|
    if type.locations.blank? and type.children.blank?
      type.destroy
      puts '[' + type.id.to_s + '] ' + type.name
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

# Fetch common names from Encyclopedia of Life (EOL)
task(:eol_names => :environment) do
  
  # Initialize csv
  CSV.open("data/eol_names.csv","wb") do |csv|
    cols = ["ff_id","ff_rank","ff_name","ff_scientific","eol_id","eol_scientific","language","eol_names"]
    csv << cols
    # For each type with a scientific name
    Type.where("scientific_name is not null and scientific_name != ''").order(:scientific_name).each{ |t|
    
      # Show progress
      puts t.scientific_name
      rank = Type::Ranks[t.taxonomic_rank]
      
      # Search EOL
      # Gets page id of first (top) result
      search_url = "http://eol.org/api/search/1.0.json?q=%22" + t.scientific_name.gsub(" ","+") + "%22&exact=true"
      search = JSON.parse(open(search_url).read)
      if search["totalResults"] > 0
        eol_id = search["results"][0]["id"]
      else
        csv << [t.id, rank, t.name, t.scientific_name, '', '', '', '']
        next
      end
      
      # Get EOL species info
      page_url = "http://eol.org/api/pages/1.0/" + eol_id.to_s + ".json?common_names=true"
      page = JSON.parse(open(page_url).read)
      eol_scientific = page["scientificName"]
      names = page["vernacularNames"].group_by{ |x| x['language'] }
      languages = names.keys
      languages.each{ |l|
        l_names = names[l].sort_by{ |n| (n.key?("eol_preferred") and n["eol_preferred"])? 0 : 1 }.collect{ |n| n["vernacularName"] }.join(", ")
        csv << [t.id, rank, t.name, t.scientific_name, eol_id, eol_scientific, l, l_names]
      }
      # Sleep
      sleep 0.1
    }
  end
end

# Fetch Wikipedia page links and parse out common names
task :wikipedia_names, [:language] => [:environment] do |t, args|
  language = args[:language] || nil

  # Initialize csv
  CSV.open("data/wikipedia_names.csv","wb") do |csv|
    cols = ["ff_id","ff_rank","ff_name","ff_scientific","language","wiki_title","wiki_url","wiki_names","ambiguous"]
    csv << cols
    # For each type
    Type.order(:scientific_name).each{ |t|
      
      # Show progress
      lang = "en"
      puts "[S] " + t.scientific_name.to_s + " [" + lang + "] " + t.name.to_s
      rank = Type::Ranks[t.taxonomic_rank]
      
      # English page title
      # from database
      if (not t.wikipedia_url.blank?)
        en_title = t.wikipedia_url.split('/').last
      # or try scientific name
      elsif (not(t.scientific_name.blank?))
        en_title = t.scientific_name
      else
        puts "=> No page title (" + lang + ")"
        #csv << [t.id, rank, t.name, t.scientific_name, lang, '', '', '', '']
        next
      end
      
      # Fetch English page
      api_url = URI.escape("https://" + lang + ".wikipedia.org/w/api.php?format=json&action=parse&redirects&page=" + en_title)
      page = JSON.parse(open(api_url).read)
      if (page.has_key?("parse") and page["parse"].has_key?("title"))
        title = page["parse"]["title"]
        url = "https://" + lang + ".wikipedia.org/wiki/" + title
        if (is_disambiguation_page(page))
          puts "=> Ambiguous (" + lang + ")"
          if lang == language
            csv << [t.id, rank, t.name, t.scientific_name, lang, title, url, '', 1]
          end
        else
          names = get_wikipedia_names(page).join(", ")
          puts "[" + lang + "] " + names
          if lang == language
            csv << [t.id, rank, t.name, t.scientific_name, lang, title, url, names, 0]
          end
        end
      else
        puts "=> No page found (" + lang + ")"
        #csv << [t.id, rank, t.name, t.scientific_name, lang, en_title, '', '', '']
        next
      end
      
      # Get other language pages
      if (page["parse"].has_key?("langlinks")) and language != "en"
        page["parse"]["langlinks"].each{ |l|
          lang = l["lang"] 
          if (language and language != lang)
            next
          end
          title = l["*"]
          url = l["url"]
          api_url = URI.escape("https://" + lang + ".wikipedia.org/w/api.php?format=json&action=parse&redirects&page=" + title)
          page = JSON.parse(open(api_url).read)
          if (is_disambiguation_page(page))
            puts "=> Ambiguous (" + lang + ")"
            csv << [t.id, rank, t.name, t.scientific_name, lang, title.to_s, url, '', 1]
          else
            names = get_wikipedia_names(page).join(", ")
            puts "[" + lang + "] " + names.to_s
            csv << [t.id, rank, t.name, t.scientific_name, lang, title.to_s, url, names.to_s, 0]
          end
        }
      end

      # Sleep
      sleep 0.1
    }
  end
end

# Helper function: Parse wikipedia common names
def get_wikipedia_names(page)
  
  # Extract common names
  content = Nokogiri::HTML(page["parse"]["text"]["*"])
  first_p = content.css('body > p')[0]
  if not first_p.nil?
    first_p.css('i').remove
    first_p_bold = first_p.css('b').collect{ |n| n.text }
  else
    first_p_bold = []
  end
  biotabox_header = content.css('table.infobox.biota th')[0]
  if (biotabox_header.nil?)
    biotabox_title = ''
  else
    biotabox_header.css('i').remove
    biotabox_title = biotabox_header.text
  end
  
  # Return as array
  temp = first_p_bold
  temp.push(biotabox_title)
  names = temp.compact.uniq.collect{ |s| s.gsub(/\.|,|\n|\t|\?|\(|\)|"/, '').strip.gsub('[ ]+', ' ') }.reject(&:blank?)
  return names
end

# Helper function: Check if page is a disambiguation page
def is_disambiguation_page(page)
  properties = page["parse"]["properties"].collect{ |p| p["name"]}
  if (properties.include?("disambiguation"))
    return true
  else
    return false
  end
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
    t = Type.where("name='Apple'").first
    Location.where("type_ids @> ARRAY[#{t.id}]").each{ |l|
      of.puts [l.lng,l.lat,l.mean_quality_rating,l.mean_yield_rating,l.observations.length].join(",")
    }
    of.close
  end

  task(:data => :environment) do
     puts "Exporting Locations..."
     cat_mask = array_to_mask(Type::DefaultCategories,Type::Categories)
     r = ActiveRecord::Base.connection.execute("SELECT locations.id, array_to_string(type_ids,':') as types, access,
       description, lat, lng, address, unverified,
       season_start, season_stop, no_season, access, unverified, author, import_id, locations.created_at, locations.updated_at
       FROM locations INNER JOIN types ON types.id=ANY(locations.type_ids) WHERE (types.category_mask & #{cat_mask})>0")
     CSV.open("public/locations.csv","wb") do |csv|
       cols = ["id","type_ids","lat","lng","unverified","description","season_start","season_stop",
               "no_season","author","address","created_at","updated_at",
               "access","quality_rating","yield_rating","import_link"]
       csv << cols
       r.each{ |row|
         csv << [row["id"],row["types"],row["lat"],row["lng"],row["unverified"],row["description"],
                 row["season_start"].nil? ? nil : I18n.t("date.month_names")[row["season_start"].to_i+1],
                 row["season_stop"].nil? ? nil : I18n.t("date.month_names")[row["season_stop"].to_i+1],
                 row["no_season"],row["author"],
                 row["address"],row["created_at"],row["updated_at"],
                 row["access"].nil? ? nil : I18n.t("locations.infowindow.access_short")[row["access"].to_i],
                 row["quality_rating"],row["yield_rating"],
                 row["import_id"].nil? ? nil : "http://fallingfruit.org/imports/#{row["import_id"]}"]
         }
     end
     puts "Exporting Types..."
     CSV.open("public/types.csv","wb") do |csv|
       cols = ["id","name","synonyms","es_name","he_name","pt_br_name","fr_name","de_name","pl_name","scientific_name",
             "scientific_synonyms","taxonomic_rank","parent_id","category_mask"]
       csv << cols
       Type.select(cols.join(",")).where("(category_mask & #{cat_mask})>0 AND NOT pending").each{ |t|
          csv << [t.id,t.name,t.synonyms,t.es_name,t.he_name,t.pt_br_name,t.fr_name,t.de_name,
                 t.pl_name,t.scientific_name,t.scientific_synonyms,
                 t.taxonomic_rank.nil? ? nil : Type::Ranks[t.taxonomic_rank],
                 t.parent_id,
                 mask_to_array(t.category_mask,Type::Categories).join(":")]
       }
     end
  end

  task(:type_template => :environment) do
    CSV.open("public/type_template.csv","wb") do |csv|
      cols = ["ID","English Common Name","Latin Name","Wikipedia Link"]
      csv << cols
      Type.all.each do |t|
        csv << [t.id,t.name,t.scientific_name,t.wikipedia_url]
      end
    end
  end

end

task(:import_type_translations => :environment) do
  I18n.available_locales.each do |l|
    next unless File.exists? "data/#{l}_names.csv"
    n = 0
    id_col = nil
    trans_cols = []
    puts l
    dbl = l.to_s.downcase.gsub("-", "_")
    CSV.foreach("data/#{l}_names.csv") do |row|
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
       n += 1
       next if n == 1 or row.join.blank?
       print "."
       location = Location.build_from_csv(row,typehash,import.default_category_mask)
       location.import = import
       location.client = 'import'
       if (location.lat.nil? or location.lng.nil?) and !location.address.blank?
         print "G"
         location.geocode
       end
       if location.valid?
         ok_count += 1
         print "S"
         if location.save and import.auto_cluster == true
           print "C"
           cluster_increment(location)
         end
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
     #FIXME _done should only contain locations imported successfully
     FileUtils.mv "public/import/#{l}", "public/import/#{import_id}_done.csv"
     puts
   } 
   dh.close
   FileUtils.rm_f "public/import/lockfile"
end
