class CreateApiLogs < ActiveRecord::Migration
  def change
    create_table :api_logs do |t|
      t.integer :n
      t.string :endpoint
      t.string :request_method
      t.text :params
      t.string :ip_address
      t.string :api_key
      t.timestamps
    end
  end
end
