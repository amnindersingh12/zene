class AddLyricsPlainToSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :songs, :lyrics_plain, :text
  end
end
