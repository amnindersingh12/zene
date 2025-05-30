class CreateSongs < ActiveRecord::Migration[8.0]
  def change
    create_table :songs do |t|
      t.string :title
      t.string :artist
      t.string :lyrics
      t.string :genius_id
      t.string :url
      t.string :pyongs_count
      t.string :description

      t.timestamps
    end
  end
end
