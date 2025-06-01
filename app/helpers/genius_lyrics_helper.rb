# app/helpers/genius_lyrics_helper.rb
require 'nokogiri'
require 'open-uri'

module GeniusLyricsHelper
  GENIUS_AUTHORIZE_URL = "https://api.genius.com/oauth/authorize".freeze
  GENIUS_TOKEN_URL = "https://api.genius.com/oauth/token".freeze
  GENIUS_REDIRECT_URI = "http://localhost:3000/auth/genius/callback".freeze # Update this!

  def fetch_and_cache_genius_lyrics(genius_song_id)
    Rails.cache.fetch("song_lyrics_text_#{genius_song_id}", expires_in: 24.hours) do
      Rails.logger.info "Attempting to fetch LYRICS (from div[data-lyrics-container='true'] with class starting 'Lyrics__Container') for Genius ID: #{genius_song_id} (using helper)"

      begin
        genius_song_data = Genius::Song.find(genius_song_id)
        debugger
        lyrics_url = genius_song_data&.url

        if lyrics_url.present?
          Rails.logger.info "Scraping LYRICS (from div[data-lyrics-container='true'] with class starting 'Lyrics__Container') from URL: #{lyrics_url} (using helper)"
          begin
            doc = Nokogiri::HTML(URI.open(lyrics_url))
            lyrics_container = doc.css('div[data-lyrics-container="true"][class^="Lyrics__Container"]')

            if lyrics_container.present?
              # Select all <p> tags within the specific lyrics container
              lyrics_paragraphs = lyrics_container.css('p').map(&:text).map(&:strip).reject(&:empty?)
              lyrics_text = lyrics_paragraphs.join("\n\n")

              if lyrics_text.present?
                Rails.logger.info "Successfully scraped LYRICS (from div[data-lyrics-container='true'] with class starting 'Lyrics__Container') for Genius ID: #{genius_song_id} (using helper)"
                lyrics_text
              else
                Rails.logger.warn "No lyrics found within <p> tags in the specific lyrics container for URL: #{lyrics_url} (using helper)"
                nil
              end
            else
              Rails.logger.warn "Specific lyrics container (div[data-lyrics-container='true'] with class starting 'Lyrics__Container') not found for URL: #{lyrics_url} (using helper)"
              nil
            end
          rescue OpenURI::HTTPError => e
            Rails.logger.error "HTTP Error fetching lyrics (from div[data-lyrics-container='true'] with class starting 'Lyrics__Container') from #{lyrics_url} (helper): #{e.message}"
            nil
          rescue SocketError => e
            Rails.logger.error "Socket error fetching lyrics (from div[data-lyrics-container='true'] with class starting 'Lyrics__Container') from #{lyrics_url} (helper): #{e.message}"
            nil
          rescue StandardError => e
            Rails.logger.error "An unexpected error occurred while fetching lyrics (from div[data-lyrics-container='true'] with class starting 'Lyrics__Container') for song ID #{genius_song_id} (helper): #{e.message}"
            nil
          end
        else
          Rails.logger.warn "Genius song URL not found for ID: #{genius_song_id} (using helper)"
          nil
        end
      rescue Genius::AuthenticationError => e
        Rails.logger.error "Genius API Authentication Error while fetching song ID #{genius_song_id} (helper): #{e.message}"
        nil
      end
    end
  end
end
