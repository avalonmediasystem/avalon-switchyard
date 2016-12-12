class Longermessage < ActiveRecord::Migration
  def change
      change_column :media_objects, :message, :text, limit: 4_294_967_295
  end
end
