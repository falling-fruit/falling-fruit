#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'cgi'
require 'csv'

if ARGV.length < 1
  $stderr.puts "Usage: kml_to_csv.rb <in.kml> <out.csv>"
  exit 1
end

if ARGV.length < 2
	csvfile = ARGV[0].sub(/\.kml/,'.csv')
else
	csvfile = ARGV[1]
end

csv = CSV.open(csvfile,"wb")
csv << ["Type","Description","Lat","Lng","Address","Season Start","Season Stop",
        "No Season","Access","Unverified","Yield Rating","Quality Rating","Author","Photo URL"]
@doc = Nokogiri::XML(File.open(ARGV[0]))

@doc.css('Placemark').each do |placemark|
  title = CGI.unescapeHTML(placemark.css('name').text)
  description = CGI.unescapeHTML(placemark.css('description').text)#.gsub!(/(<[^>]*>)|\t/) {""}
  coordinates = placemark.at_css('coordinates')
  lat = nil
  lng = nil
  coordinates.text.split(' ').each do |coordinate|
    (lng,lat,elevation) = coordinate.split(',').collect{ |e| e.to_f }
  end if coordinates
  csv << [title,description,lat,lng,nil,nil,nil,nil,nil,nil,nil,nil,nil]
end

csv.close