#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'csv'

if ARGV.length < 2
  $stderr.puts "Usage: kml_to_csv.rb <in.kml> <out.csv>"
  exit 1
end

csv = CSV.open(ARGV[1],"wb")
csv << ["Type","Type Other","Description","Lat","Lng","Address","Season Start",
        "Season Stop","No Season","Access","Unverified","Yield Rating","Quality Rating","Author"]
@doc = Nokogiri::XML(File.open(ARGV[0]))

@doc.css('Placemark').each do |placemark|
  title = placemark.css('name').text
  description = placemark.css('description').text.gsub!(/(<[^>]*>)|\n|\t/s) {""}
  coordinates = placemark.at_css('coordinates')
  lat = nil
  lng = nil
  coordinates.text.split(' ').each do |coordinate|
    (lng,lat,elevation) = coordinate.split(',')
  end if coordinates
  csv << [nil,nil,[title,description].join(";"),lat,lng,nil,nil,nil,nil,nil,nil,nil,nil,nil]
end

csv.close
