#!/usr/bin/env ruby

require 'benchmark'
require 'net/http'
require 'csv'

WHICH = ARGV[0]
CSV_PATH = ARGV[1]
DEBUG = ARGV[2]

def point_to_box(lat, lng, width)
  width = width.to_f
  return [
    [lat - width / 2, -85].max,
    [lng - width / 2, -180].max,
    [lat + width / 2, 85].min,
    [lng + width / 2, 180].min
  ]
end

def box_to_old_bounds(box)
  return "swlat=#{box[0]}&swlng=#{box[1]}&nelat=#{box[2]}&nelng=#{box[3]}"
end

def box_to_new_bounds(box)
  return "bounds=#{box[0]},#{box[1]}%7C#{box[2]},#{box[3]}"
end

width = WHICH == 'locations' ? 0.1 : 2

puts "old\tnew\tnewer"
CSV.parse(File.read(CSV_PATH), headers: true, converters: :numeric).each do |row|
  box = point_to_box(row['lat'], row['lng'], width)
  old_bounds = box_to_old_bounds(box)
  new_bounds = box_to_new_bounds(box)
  if WHICH == 'clusters'
    z = 13
    # Clusters not supported in v0.1
    url_old = URI("http://fallingfruit.org/api/locations/cluster.json")
    # Uses 2^zoom+1, but with zoom only up to 12
    url_new = URI("http://fallingfruit.org/api/0.2/clusters.json?#{old_bounds}&zoom=#{z - 1}&api_key=BJBNKMWM")
    url_newer = URI("http://fallingfruit.org/api/0.3/clusters?#{new_bounds}&zoom=#{z}&api_key=BJBNKMWM")
  else
    # Muni off by default
    url_old = URI("http://fallingfruit.org/api/locations/markers.json?#{old_bounds}&api_key=BJBNKMWM&muni=1")
    url_new = URI("http://fallingfruit.org/api/0.2/locations.json?#{old_bounds}&api_key=BJBNKMWM")
    url_newer = URI("http://fallingfruit.org/api/0.3/locations?#{new_bounds}&api_key=BJBNKMWM")
  end
  unless DEBUG.nil?
    $stderr.puts url_old
    $stderr.puts url_new
    $stderr.puts url_newer
  end
  time_old = Benchmark.realtime{
    begin
      Net::HTTP.get(url_old)
    rescue Net::ReadTimeout
    end
  }
  time_new = Benchmark.realtime{
    begin
      Net::HTTP.get(url_new)
    rescue Net::ReadTimeout
    end
  }
  time_newer = Benchmark.realtime{
    begin
      Net::HTTP.get(url_newer)
    rescue Net::ReadTimeout
    end
  }
  puts "#{time_old}\t#{time_new}\t#{time_newer}"
end
