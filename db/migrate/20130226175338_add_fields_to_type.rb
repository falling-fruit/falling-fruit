class AddFieldsToType < ActiveRecord::Migration
  def up
    remove_column :locations, :cultivar
    change_table :types do |t|
      t.string :wikipedia_url
      t.string :edability
      t.text :notes
      t.string :synonyms
      t.string :scientific_synonyms
    end
  end
  def down
    change_table :locations do |t|
      t.string :cultivar
    end
    remove_column :types, :wikipedia_url
    remove_column :types, :edability
    remove_column :types, :notes
    remove_column :types, :synonyms
    remove_column :types, :scientific_synonyms
  end
end
