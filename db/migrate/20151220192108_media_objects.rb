class MediaObjects < ActiveRecord::Migration
  def change
    create_table :media_objects do |t|
      t.string :group_name
      t.string :status
      t.boolean :error
      t.string :message
      t.string :created
      t.string :last_modified
      t.string :avalon_chosen
      t.string :avalon_pid
      t.string :avalon_url
      t.boolean :locked
    end
  end
end
