class AddFullnameToCollections < ActiveRecord::Migration[4.2]
  def change
    add_column :collections, :fullname, :string
  end
end
