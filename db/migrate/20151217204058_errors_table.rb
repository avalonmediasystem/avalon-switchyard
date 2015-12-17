class ErrorsTable < ActiveRecord::Migration
  def change
    create_table :errors do |t|
      t.string :mco_id
      t.string :error_time
      t.string :error_message
      t.string :error_code
    end
  end
end
