#!/usr/bin/env ruby

require '../config/environment'

n = ApiLog.count
i = 0

CSV.open("boundingboxes.csv", "wb") do |csv|
  csv << ["created_at","iphash","nelat","nelng","swlat","swlng"]
  while i < n
    puts i
    ApiLog.select("params,created_at,ip_address").where("endpoint='api/locations/markers'").limit(1000).offset(i).each{ |log|
      params = Marshal.load(Base64.decode64(log.params))
      csv << [log.created_at,Digest::SHA1.hexdigest(log.ip_address)] + ["nelat","nelng","swlat","swlng"].collect{ |i| params[i] }
    }
    csv.flush()
    i += 1000
  end
end
