#!/usr/bin/env ruby

require 'benchmark'
require 'net/http'
require 'csv'
require 'base64'
require 'active_support/core_ext/hash/indifferent_access'

LatMin = -85.0
LatMax = 85.0
LngMin = -180.0
LngMax = 180.0
N = 1000

Which = ARGV[0]
ParamsCSV = ARGV[1]

def rand_box
  swlng = (LngMax-LngMin)*rand + LngMin
  swlat = (LatMax-LatMin)*rand + LatMin
  nelng = (LngMax-swlng)*rand + swlng
  nelat = (LatMax-swlat)*rand + swlat
  return "nelat=#{nelat}&nelng=#{nelng}&swlat=#{swlat}&swlng=#{swlng}"
end

def params_box(p)
  return "nelat=#{p[:nelat]}&nelng=#{p[:nelng]}&swlat=#{p[:swlat]}&swlng=#{p[:swlng]}"
end

puts "old new"

unless ParamsCSV.nil?
  n = 0
  params = []
  CSV.foreach(ParamsCSV) do |row|
    n += 1
    next if n == 1
    p = Marshal.load(Base64.decode64(row[0]))
    params.push(p) if p[:nelat]
  end
  params.shuffle!
end

(1..N).each{ |i|
  unless ParamsCSV.nil?
    if Which == "cluster"
      url_old = URI("http://fallingfruit.org/api/locations/cluster.json?#{params_box(params[i])}&grid=#{params[i][:grid]}&api_key=BJBNKMWM")
      url_new = URI("http://fallingfruit.org/api/0.2/clusters.json?#{params_box(params[N+i])}&zoom=#{params[N+i][:grid]}&api_key=BJBNKMWM")
    else
      url_old = URI("http://fallingfruit.org/api/locations/cluster.json?#{rand_box}&api_key=BJBNKMWM")
      url_new = URI("http://fallingfruit.org/api/0.2/clusters.json?#{rand_box}&api_key=BJBNKMWM")
    end
  else
    if Which == "cluster"
      z = (12*rand).ceil
      url_old = URI("http://fallingfruit.org/api/locations/cluster.json?#{rand_box}&grid=#{z}&api_key=BJBNKMWM")
      url_new = URI("http://fallingfruit.org/api/0.2/clusters.json?#{rand_box}&zoom=#{z}&api_key=BJBNKMWM")
    else
      url_old = URI("http://fallingfruit.org/api/locations/markers.json?#{rand_box}&api_key=BJBNKMWM")
      url_new = URI("http://fallingfruit.org/api/0.2/locations.json?#{rand_box}&api_key=BJBNKMWM")
    end
  end
  $stderr.puts url_old
  $stderr.puts url_new
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
  puts "#{time_old} #{time_new}"
}
