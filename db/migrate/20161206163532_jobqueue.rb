class Jobqueue < ActiveRecord::Migration[4.2]
  def change
    add_column :media_objects, :api_hash, :text, limit: 4_294_967_295
  end
end
