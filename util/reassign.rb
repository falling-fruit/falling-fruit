#!/usr/bin/env ruby
require 'csv'
puts "BEGIN;"
CSV.open(ARGV[0],"r"){ |csv|
  csv.each{ |l|
    puts "UPDATE locations_types SET type_id=(SELECT id FROM types WHERE name='#{l[1]}') WHERE location_id=#{l[0]};"
  }
}
puts "COMMIT;"
