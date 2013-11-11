class AddTypeToClusters < ActiveRecord::Migration
  def change
    change_table :clusters do |t|
      t.references :type
    end
  end
end
