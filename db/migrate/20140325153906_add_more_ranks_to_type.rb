class AddMoreRanksToType < ActiveRecord::Migration
  def change
    old_ranks={0 => "Species", 1 => "Genus", 2 => "Family", 3 => "Order", 4 => "Class", 5 => "Phylum", 6 => "Kingdom"}
    lookup = Type::Ranks.invert
    Type.where("taxonomic_rank IS NOT NULL").each{ |t|
      t.taxonomic_rank = lookup[old_ranks[t.taxonomic_rank]]
      t.save
    }
  end
end