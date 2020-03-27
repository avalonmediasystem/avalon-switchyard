class Longermessage < ActiveRecord::Migration[4.2]
  def change
      change_column :media_objects, :message, :text, limit: 4_294_967_295
  end
end
