class AddObservationIdToChanges < ActiveRecord::Migration
  def change
    add_column :changes, :observation_id, :integer
    add_column :changes, :author, :string
    add_column :changes, :description_patch, :text
    Change.where("description='added'").each{ |c|
      unless c.location.nil?
        c.author = c.location.author
        c.save
      end
    }
  end
end
