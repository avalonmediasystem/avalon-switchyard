class Messages < ActiveRecord::Migration
  def change
    change_table :media_objects do |t|
      t.string :message
      t.remove :error_message
    end
  end
end
