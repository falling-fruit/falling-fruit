require '../../config/environment'
require 'rgeo'

# ADW	"A" designated weed
# AW	A list (noxious weeds)
# BDW	"B" designated weed
# BW	B list (noxious weeds)
# CAT1	Category 1 noxious weed
# CAT2	Category 2 noxious weed
# CAT3	Category 3 noxious weed
# CAW	Class A noxious weed
# CBW	Class B noxious weed
# CCW	Class C noxious weed
# CW	C list (noxious weeds)
# IAP	Invasive aquatic plant
# IB	Invasive, banned
# ILAP	Invasive aquatic plant
# INB	Invasive, not banned
# NAW	Noxious aquatic weed
# NP	Noxious plant
# NUW	Nuisance weed
# NW	Noxious weed
# NWSPQ	Noxious weed seed and plant quarantine
# P	Prohibited
# PAP1	Prohibited aquatic plant, Class 1
# PAP2	Prohibited aquatic plant, Class 2
# PIB	Potentially invasive, banned
# PINB	Potentially invasive, not banned
# PIS	Prohibited invasive Species
# PN	Public nuisance
# PNW	Prohibited noxious weed
# PP	Plant pest
# PR	Permit required
# PRNW	Primary noxious weed
# Q	Quarantine
# QW	Q list (temporary "A" list noxious weed, pending final determination)
# RGNW	Regulated noxious weeds
# RNPS	Regulated non-native plant species
# RNW	Restricted noxious weed
# SNW	Secondary noxious weed
# SP	Sale prohibited
# WAWQ	Wetland and aquatic weed quarantine
Noxious = ["ADW","AW","BDW","BW","CAT1","CAT2","CAT3","CAW","CBW","CC","CW","IAP","IB","ILAP","INB","NAW","NP","NW","NUW","PNW","PRNW","RGNW","RNW","SNW"]

SRID=4269 # NAD83

n = 0
state_hash = {}
CSV.foreach("usda.csv") do |row|
  n += 1
  next if n == 1
  #"Symbol","Synonym Symbol","Scientific Name","Common Name","Federal Noxious Status","State Noxious Status","Native Status"
  latin_name = row[2].gsub(" L.","").strip
  common_name = row[3].strip
  if common_name.blank?
    tids = Type.select("id").where("scientific_name ILIKE ?","%#{latin_name}%").collect{ |r| r.id }
  else
    tids = Type.select("id").where("scientific_name ILIKE ? OR name ILIKE ?","%#{latin_name}%","%#{common_name}%").collect{ |r| r.id }
  end
  next if tids.nil? or tids.empty?
  puts "#{common_name} #{latin_name} #{tids.join(",")}"
  row[5].split(/, /).each{ |r|
    if r =~ /([A-Z]{2}) \((.*)\)/
      state = $1
      status = $2.split(/, /)
      next unless status.any?{ |s| Noxious.include? s }
      state_hash[state] = [] if state_hash[state].nil?
      state_hash[state] += tids
    end
  }
end

RGeo::Shapefile::Reader.open('cb_2014_us_state_20m.shp') do |file|
  puts "File contains #{file.num_records} records."
  file.each do |record|
    state = record.attributes["STUSPS"]
    geom = record.geometry.as_text
    types = state_hash[state]
    next if types.nil? or types.empty?
    puts "#{state} #{types.join(",")}" 
    # FIXME: insert into invasives table once it exists
  end
end
