class AddTranslationFieldsToTypes < ActiveRecord::Migration
  def change
    add_column :types, :fr_name, :string
    add_column :types, :pt_br_name, :string
    add_column :types, :de_name, :string
  end
end
