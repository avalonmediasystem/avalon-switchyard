class AddFullnameToCollections < ActiveRecord::Migration
  def change
    add_column :collections, :fullname, :string
  end
end
