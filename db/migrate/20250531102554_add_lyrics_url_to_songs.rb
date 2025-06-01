class AddLyricsUrlToSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :songs, :lyrics_url, :string
  end
end
