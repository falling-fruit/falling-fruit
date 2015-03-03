class TypeOthersIntoTypes < ActiveRecord::Migration
  def up
    add_column :types, :pending, :boolean, :default => true
    Type.all.each{ |t| t.pending = false; t.save }
    h = {}
    Location.where("type_others IS NOT NULL").select("id,type_others").each{ |l|
      l.type_others.compact.each{ |e|
        safer_type = e.squish.tr('^A-Za-z- \'','').capitalize
        next if safer_type.blank?
        h[safer_type] = [] if h[safer_type].nil?
        h[safer_type] << l.id
      }
    }
    h.keys.each{ |k|
      puts "#{k}: #{h[k].length}"
      t = Type.new
      t.name = k
      t.category_mask = 0
      t.pending = true
      t.save
      h[k].each{ |lid|
        l = Location.find(lid)
        l.types << t.id
        l.save
      }
    }
    remove_column :locations, :type_others
  end

  def down
  end
end
