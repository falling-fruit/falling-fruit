class AddHoneybeeTypes < ActiveRecord::Migration
  def up
    add_column :types, :category_mask, :integer, :default => 1
    n = 0
    bee_bit = Type::Categories.index("honeybee")
    n_new = 0
    n_existing = 0
    CSV.foreach("data/bee_types.csv") do |row|
      n += 1
      next if n == 1
      cname = row[0]
      lname = row[1]
      cname_norm = cname.squish.tr('^A-Za-z- \'','').capitalize
      lname_norm = lname.squish.tr('^A-Za-z- \'','').capitalize
      match = Type.where("name=? OR scientific_name=?",cname_norm,lname_norm)
      if match.empty?
        t = Type.new({:name => cname_norm,:scientific_name => lname_norm, :category_mask => (1<<bee_bit) })
        t.save
        $stderr.puts "+ #{cname_norm}"
        n_new += 1
      else
        match.each{ |t|
          t.category_mask = (t.category_mask & (1<<bee_bit))
          t.save
          $stderr.puts "~ #{cname_norm} - #{lname_norm}"
          n_existing += 1
        }
      end
    end
    $stderr.puts "#{n_new} new types, #{n_existing} existing were honeybee-ized"
  end
  def down
    remove_column :types, :category_mask
  end
end
