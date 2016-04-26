#!/usr/bin/env ruby

require '../config/environment'

require 'open-uri'
require 'json'

Endpoint='http://api.inaturalist.org/v1/observations?geo=true&identified=true&photos=true&license=cc-by,cc-by-nc,cc-by-sa,cc-by-nc-sa,cc0&photo_license=cc-by,cc-by-nc,cc-by-sa,cc-by-nc-sa,cc0&rank=species,hybrid,subspecies,variety,form&identifications=most_agree&order=desc&order_by=created_at'
PerPage=50

import_name = "iNaturalist"
i = Import.where("name = ?",import_name)
if i.empty?
  i = Import.new
  i.url = "https://www.inaturalist.org/"
  i.name = import_name
  i.comments = "Creative Commons Share-Alike and Noncommercial data from the iNaturalist API"
  i.save
else
  i = i.first
end

ids = Location.select("inaturalist_id").where("inaturalist_id IS NOT NULL").collect{ |x| x.inaturalist_id.to_i }
puts ids

page = 1
todo = nil
while todo.nil? or ((page-1)*PerPage < todo)
  puts "page #{page}"
  url = Endpoint + "&per_page=#{PerPage}&page=#{page}"
  json = JSON.load(open(url))
  todo = json["total_results"]
  page = json["page"] + 1
  json["results"].each{ |result|
    id = result["id"]
    print id
    if ids.include? id.to_i
      puts "...done"
      next
    end

    l = Location.new
    o = Observation.new
    o.observed_on = result["observed_on_details"]["date"] unless result["observed_on_details"].nil?

    tids = [] 
    species_guess = result["species_guess"]
    unless result["taxon"].nil?
      species_scientific = result["taxon"]["name"]
      species_common = result["taxon"]["preferred_common_name"]
      tids += Type.select("id").where("scientific_name ILIKE ?","%#{species_scientific}%").collect{ |r| r.id } unless species_scientific.nil?
      tids += Type.select("id").where("name ILIKE ?","%#{species_common}%").collect{ |r| r.id } if !species_common.nil? and tids.empty?
    end
    species_guess = result["species_guess"]
    tids += Type.select("id").where("name ILIKE ?","%#{species_guess}%").collect{ |r| r.id } if !species_guess.nil? and tids.empty?
    if tids.compact.empty?
      puts "...no type"
      next
    else
      puts "Candidate types: #{tids.join(",")}"
    end

    unless result["photos"].empty? or result["photos"][0]["url"].nil?
      photo_url = result["photos"][0]["url"]
      photo_url.gsub!(/square/i,"large") if photo_url =~ /square/
      puts photo_url
      o.photo = open(photo_url)
    end

    next if result["geojson"].nil? or result["geojson"]["coordinates"].nil?
    l.lng = result["geojson"]["coordinates"][0]
    l.lat = result["geojson"]["coordinates"][1]
    l.author = result["user"]["login"]
    o.author = l.author
    l.description = result["uri"]
    l.type_ids = [tids[0]]
    l.import_id = i.id
    l.inaturalist_id = id

    l.observations << o

    l.save
    o.save

    puts "...okay (type = #{tids.first}, location = #{l.id})"
  }
end
