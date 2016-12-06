class Jobqueue < ActiveRecord::Migration
  def change
    add_column :media_objects, :api_hash, :text, limit: 4294967295
  end
end
