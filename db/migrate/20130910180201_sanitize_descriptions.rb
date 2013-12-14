class SanitizeDescriptions < ActiveRecord::Migration
  def up
    puts "Sanitizing Descriptions"
    n = 0
    c = Location.all.count
    Location.where("description IS NOT NULL").each{ |l|
      next if l.description.nil?
      l.description = l.description.strip
      next if l.description.length == 0
      l.description = ActionController::Base.helpers.sanitize(l.description,tags:["br"]).gsub("<br>","\n")
      l.save(:validate => false)
      n += 1
      puts "#{100.0*n.to_f/c.to_f}%" if n % 1000 == 0
    }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
