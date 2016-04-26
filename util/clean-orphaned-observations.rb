#!/usr/bin/env ruby

require '../config/environment'

c = 0
Observation.all.each{ |o|
  next unless o.location.nil?
  unless o.photo.nil?
    o.photo = nil
    o.save
  end
  o.destroy
  puts o.id
  c += 1
}
puts c
