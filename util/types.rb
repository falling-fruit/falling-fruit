#!/usr/bin/env ruby
require 'csv'
require 'pg'

# Note: Bug---this will put a bunch of empty-string synonyms in the DB which mightn't be what you want
# you can clean up later with:

def e(str)
  str.nil? ? nil : PGconn::escape(str)
end

puts "BEGIN;"
CSV.open(ARGV[0],"r"){ |csv|
  # Tasks,ID,Common,Common Syn,Scientific,Scientific Syn,Wkipedia,Rating,Notes,USDA Symbol,USDA Scientific
  n = 0
  csv.each{ |row|
    n += 1
    next if n == 1
    tasks,id,common,synonyms,scientific,scientific_syn,wp,rating,notes,usda,usda_scientific = row
    next if id.nil? or id.strip == ""
    id = id.to_i
    rating = (rating.nil? or rating.strip == "") ? "NULL" : rating.to_i
    puts "UPDATE types SET name='#{e(common)}', synonyms='#{e(synonyms)}', scientific_name='#{e(scientific)}', scientific_synonyms='#{e(scientific_syn)}', wikipedia_url='#{e(wp)}',usda_symbol='#{e(usda)}',edability=#{rating},notes='#{e(notes)}' WHERE id=#{id};"
    
  }
}
puts "COMMIT;"
