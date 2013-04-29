class AddLicenseToImport < ActiveRecord::Migration
  def change
    change_table :imports do |t|
      t.text :license
    end
  end
end
