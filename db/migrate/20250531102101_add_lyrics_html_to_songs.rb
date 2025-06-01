class AddLyricsHtmlToSongs < ActiveRecord::Migration[8.0]
  def change
    add_column :songs, :lyrics_html, :text
  end
end
