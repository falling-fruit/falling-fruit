class AddLocaleToEnglishNames < ActiveRecord::Migration
  def up
    rename_column :types, :name, :en_name
    rename_column :types, :synonyms, :en_synonyms
  end
  def down
    rename_column :types, :en_name, :name
    rename_column :types, :en_synonyms, :synonyms
  end
end
