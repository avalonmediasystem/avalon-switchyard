class Collections < ActiveRecord::Migration[4.2]
  def change
    create_table :collections do |t|
      t.string :name
      t.string :pid
      t.string :avalon_url
    end
  end
end
