#!/usr/bin/env ruby

require '../../config/environment'

require 'open-uri'
require 'json'

Endpoint="http://api.inaturalist.org/v1/observations?project_id=edible-flora&order=desc&order_by=created_at"
json = JSON.load(open(Endpoint))

import_name = "iNaturalist - Edible Flora Project"
i = Import.where("name = ?",import_name)
if i.empty?
  i = Import.new
  i.url = "https://www.inaturalist.org/projects/edible-flora"
  i.name = import_name
  i.comments = "Edible flora imported from the iNaturalist API"
else
  i = i.first
end

ids = Location.select("inaturalist_id").where("inaturalist_id IS NOT NULL")

json["results"].each{ |result|
  print id
  id = result["id"]
  if ids.include? id
    puts "...done"
    next
  end

  l = Location.new
  o = Observation.new
  o.observed_on = result["observed_on_details"]["date"]
  
  species_guess = result["species_guess"]
  species_scientific = result["taxon"]["name"]
  species_common = result["taxon"]["preferred_common_name"]

  tids = Type.select("id").where("scientific_name ILIKE ?","%#{species_scientific}%").collect{ |r| r.id }
  tids = Type.select("id").where("name ILIKE ?","%#{species_common}%").collect{ |r| r.id } if tids.empty?
  tids = Type.select("id").where("name ILIKE ?","%#{species_guess}%").collect{ |r| r.id } if tids.empty?

  if tids.empty?
    puts "...no type"
    next
  end

  l.lng = result["geojson"]["coordinates"][0]
  l.lat = result["geojson"]["coordinates"][1]
  l.author = result["user"]["login"]
  l.description = result["uri"]
  l.type_ids << tids.first

  l.observations << o

#  l.save
}
