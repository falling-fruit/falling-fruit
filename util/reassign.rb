#!/usr/bin/env ruby
# WARNING: doesn't work w/current schema
require 'csv'
puts "BEGIN;"
CSV.open(ARGV[0],"r"){ |csv|
  n = 0
  csv.each{ |l|
    n += 1
    next if n == 1
    id,names = l
    puts "DELETE FROM locations_types WHERE id=#{id};"
    names.split(/,/).each{ |name|
      name = name.strip
      puts "INSERT INTO locations_types (location_id,type_id) VALUES (#{id},(SELECT id FROM types WHERE name='#{name}'));"
    }
  }
}
puts "COMMIT;"
