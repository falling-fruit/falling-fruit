class AddParentIdToTypes < ActiveRecord::Migration
  def change
    add_column :types, :parent_id, :integer
    add_column :types, :taxonomic_rank, :integer
    add_column :types, :es_name, :string # Spanish (Generic/Spain)
    add_column :types, :he_name, :string # Hebrew (Israel)
    add_column :types, :pl_name, :string # Polish (Poland)
  end
end
