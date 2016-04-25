#!/usr/bin/env ruby

require '../config/environment'

require 'open-uri'
require 'json'

Endpoint="http://api.inaturalist.org/v1/observations?project_id=edible-flora&order=desc&order_by=created_at"
PerPage=50
json = JSON.load(open(Endpoint))

import_name = "iNaturalist - Edible Flora Project"
i = Import.where("name = ?",import_name)
if i.empty?
  i = Import.new
  i.url = "https://www.inaturalist.org/projects/edible-flora"
  i.name = import_name
  i.comments = "Edible flora imported from the iNaturalist API"
  i.save
else
  i = i.first
end

ids = Location.select("inaturalist_id").where("inaturalist_id IS NOT NULL").collect{ |x| x.inaturalist_id }
puts ids

page = 1
todo = nil
while todo.nil? or ((page-1)*PerPage < todo)
  puts "page #{page}"
  json = JSON.load(open(Endpoint + "&per_page=#{PerPage}&page=#{page}"))
  todo = json["total_results"]
  page = json["page"] + 1
  json["results"].each{ |result|
    id = result["id"]
    print id
    if ids.include? id
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
    end
    tids = Type.select("id").where("scientific_name ILIKE ?","%#{species_scientific}%").collect{ |r| r.id } unless result["taxon"].nil?
    tids = Type.select("id").where("name ILIKE ?","%#{species_common}%").collect{ |r| r.id } if tids.empty? unless result["taxon"].nil?
    tids = Type.select("id").where("name ILIKE ?","%#{species_guess}%").collect{ |r| r.id } if tids.empty?

    if tids.empty?
      puts "...no type"
      next
    end

    next if result["geojson"].nil? or result["geojson"]["coordinates"].nil?
    l.lng = result["geojson"]["coordinates"][0]
    l.lat = result["geojson"]["coordinates"][1]
    l.author = result["user"]["login"]
    o.author = l.author
    l.description = result["uri"]
    l.type_ids = [tids.first]
    l.import_id = i.id
    l.inaturalist_id = id

    l.observations << o

    l.save
    o.save

    puts "...okay (type = #{tids.first}, location = #{l.id})"
  }
end
