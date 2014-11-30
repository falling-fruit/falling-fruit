#!/usr/bin/env ruby
# improved from https://github.com/caseypt/map-gather/blob/master/map_gather.rb

require 'rubygems'
require 'json'
require 'csv'
require 'enumerator'
require 'rest_client'

# Check to make sure we have all the required arguments
def startup_check
  if ARGV.empty? || ARGV[0].nil?
    abort("You must specify a ArcGIS REST Query URL (and optionally, an output file name): " +
      "ruby map-gather.rb http://www.example.com/ArcGIS/rest/services/folder_name/map_name/MapServer/layer_index/ (resultOffset = 0) (outfile = <layer name>)"
    )
  end

  $url = ARGV[0]
  if ARGV[1].nil?
    $resultOffset = 0
  else
    $resultOffset = ARGV[1].to_i
  end
  if not ARGV[2].nil?
    $outfile = ARGV[2]
  end
end

# Get a list of all the ObjectIDS for the specified layer (i.e. layer_index section of $url)
def get_oids
  params = {
    :where => "#{$objectIdField} IS NOT NULL",
    :returnIdsOnly => true,
    :f => 'pjson'
  }

  RestClient.get("#{$url}/query", { :params => params }){ |response, request, result, &block|
    case response.code
    when 200
      parse_oids(response)
    else
      puts "Error"
      response.return!(request, result, &block)
    end
  }
end

# Turn the JSON OID query response into an array of OIDS
def parse_oids(response)
  oids = []

  JSON.parse(response.body)["objectIds"].each do |oid|
    oids.push(oid)
  end

  oids
end

# Get features
def get_features() 
  
  # Get layer properties
  RestClient.get("#{$url}/?f=pjson"){ |response, request, result, &block|
      case response.code
      when 200
        parse = JSON.parse(response.body)
        # load properties
        abort("geometryType is not 'esriGeometryPoint'") if (parse["geometryType"] != "esriGeometryPoint")
        abort("supportedQueryFormats does not include 'JSON'") if (!parse["supportedQueryFormats"].nil? and !parse["supportedQueryFormats"].include?("JSON"))
        abort("capabilities does not include 'Query'") if (!parse["capabilities"].include?("Query"))
        $supportsPagination = (parse["advancedQueryCapabilities"].nil? or parse["advancedQueryCapabilities"]["supportsPagination"] == false)? false : true
        $maxRecordCount = parse["maxRecordCount"]       
        if $outfile.nil?
          $outfile = "#{parse["name"]}.csv"
        end
        # write field metadata
        fields = parse["fields"]
        File.open("#{$outfile.chomp(File.extname($outfile))}_fields.json","w"){ |f|
          f << JSON.pretty_generate(fields)
        }
        # choose OID field
        $objectIdField = parse["objectIdField"].nil? ? (fields.detect{ |h| h['type'] == 'esriFieldTypeOID' }['name']) : parse["objectIdField"]
        # Print
        puts "Name: #{parse["name"]}" 
        puts "OID Field: #{$objectIdField}"
        puts "supportsPagination: #{$supportsPagination}"
        puts "maxRecordCount: #{$maxRecordCount}"
      else
        puts "ERROR"
        response.return!(request, result, &block)
      end
    }
  
  # Initialize parameters
  params = {
    :outFields => '*',
    :returnGeometry => true,
    :f => 'pjson',
    :outSR => 4326,
    :geometryType => 'esriGeometryPoint'
  }
  
  # Get total count
  params["returnCountOnly"] = true
  params["where"] = "1=1"
  RestClient.get("#{$url}/query", {:params => params}){ |response, request, result, &block|
      case response.code
      when 200
        $totalCount = JSON.parse(response.body)["count"]
        puts "Found #{$totalCount} features."
      else
        puts "ERROR"
        response.return!(request, result, &block)
      end
    }
  
  ## Get features
  $csv = CSV.open($outfile, "w")
  params["returnCountOnly"] = false
  
  # OIDs
  if $supportsPagination == false and ($maxRecordCount.nil? or $maxRecordCount < $totalCount)
    puts "Pagination not supported. Using OID blocks."
    oids = (get_oids)[$resultOffset..-1]
    oids.each_slice(100) do |ids|
      params["where"] = "#{$objectIdField} IN (#{ids[0...101].join(',')})"
      RestClient.get("#{$url}/query", {:params => params }){ |response, request, result, &block|
        case response.code
        when 200
          resultCount = parse_features(response)
          update_percentage($resultOffset, resultCount, $totalCount)
          $resultOffset = $resultOffset + resultCount
        else
          puts "error"
          response.return!(request, result, &block)
        end
      }
    end
    
  # Pagination
  else
    params["resultRecordCount"] = $maxRecordCount # wouldn't work otherwise!?
    while $resultOffset < $totalCount
      params["resultOffset"] = $resultOffset
      RestClient.get("#{$url}/query", {:params => params} ){ |response, request, result, &block|
        case response.code
        when 200
          resultCount = parse_features(response)
          update_percentage($resultOffset, resultCount, $totalCount)
          $resultOffset = $resultOffset + resultCount
        else
          puts "ERROR"
          response.return!(request, result, &block)
        end
      }
    end
  end
  
  # Close file
  $csv.close()
end

# Parse and write the returned features to the output CSV file
def parse_features(response)
  features = JSON.parse(response.body)["features"]
  
  features.each do |feature|
    if feature["geometry"].nil?
      next
    end
    if $header == false
      $csv << feature["attributes"].keys.concat(feature["geometry"].keys)
      $header = true
    end
    $csv << feature["attributes"].values.concat(feature["geometry"].values)
  end
  features.length
end

# Show the user how far along the feature gathering/writing process is
def update_percentage(resultOffset, resultCount, totalCount)
  percent = ((resultOffset + resultCount).to_f() / totalCount.to_f()) * 100
  puts "#{resultOffset + 1} - #{resultOffset + resultCount} (#{percent.round(0)}%)"
  sleep 0.1 # throttle requests
end

# Run
startup_check
puts "Creating output file."
$header = false
get_features
puts "Done!"