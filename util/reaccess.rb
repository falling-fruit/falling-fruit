#!/usr/bin/env ruby
require 'csv'
puts "BEGIN;"
CSV.open(ARGV[0],"r"){ |csv|
  n = 0
  csv.each{ |l|
    n += 1
    next if n == 1
    type,type_other,description,lat,lng,address,season_start,season_stop,no_season,access,unverified,yield_rating,quality_rating,author,photo_url = l
    puts "UPDATE locations SET access=#{access} WHERE lat=#{lat} AND lng=#{lng};"
  }
}
puts "COMMIT;"
