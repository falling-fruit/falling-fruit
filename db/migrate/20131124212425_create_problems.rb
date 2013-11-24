class CreateProblems < ActiveRecord::Migration
  def change
    create_table :problems do |t|
      t.integer :problem_code
      t.text :comment
      t.integer :resolution_code
      t.text :response
      t.integer :reporter_id
      t.integer :responder_id
      t.references :location

      t.timestamps
    end
    add_index :problems, :reporter_id
    add_index :problems, :responder_id
    add_index :problems, :location_id
  end
end
