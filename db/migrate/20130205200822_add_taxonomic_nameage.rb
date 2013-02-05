class AddTaxonomicNameage < ActiveRecord::Migration
  def up
    change_table :locations do |t|
      t.string :cultivar
    end
    change_table :types do |t|
      t.string :scientific_name
      t.string :usda_symbol
    end  
  end

  def down
    remove_column :locations, :cultivar
    remove_column :types, :scientific_name
    remove_column :types, :usda_symbol
  end
end
