class SanitizeDescriptions < ActiveRecord::Migration
  def up
    Location.all.each{ |l|
      next if l.description.nil?
      l.description = l.description.strip
      next if l.description.length == 0
      l.description = ActionController::Base.helpers.sanitize(l.description,tags:["br"]).gsub("<br>","\n")
      l.save
    }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
