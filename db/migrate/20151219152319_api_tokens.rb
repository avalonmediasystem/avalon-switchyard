class ApiTokens < ActiveRecord::Migration
  def change
    create_table :api_tokens do |t|
      t.string :token
      t.string :creation_time
      t.boolean :active
      t.string :notes
    end
  end
end
