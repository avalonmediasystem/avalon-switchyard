class ApiTokens < ActiveRecord::Migration[4.2]
  def change
    create_table :api_tokens do |t|
      t.string :token
      t.string :creation_time
      t.boolean :active
      t.string :notes
    end
  end
end
