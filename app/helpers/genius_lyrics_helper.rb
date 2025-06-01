# app/helpers/genius_lyrics_helper.rb
require "nokogiri"
require "open-uri"

module GeniusLyricsHelper
  def fetch_and_cache_genius_lyrics(genius_song_id)
    Rails.cache.fetch("song_lyrics_text_#{genius_song_id}", expires_in: 24.hours) do
      Rails.logger.info "Attempting to fetch LYRICS for Genius ID: #{genius_song_id} (helper)"
      fetch_lyrics_text(genius_song_id)
    end
  end

  def fetch_lyrics_text(genius_song_id)
  genius_song_object = Genius::Song.find(genius_song_id)
  return nil unless genius_song_object&.url.present?
  lyrics_url = genius_song_object.url

  Rails.logger.info "Attempting to fetch HTML from URL: #{lyrics_url} for Genius ID: #{genius_song_id}"
  begin
    # Consider adding User-Agent headers to look more like a browser
    # html_file = URI.open(lyrics_url, "User-Agent" => "Mozilla/5.0 ...")
    # doc = Nokogiri::HTML(html_file)
    doc = Nokogiri::HTML(URI.open(lyrics_url, "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"))


    # --- THIS IS THE CRITICAL PART TO GET RIGHT ---
    # Find the main container for lyrics. This selector NEEDS to be verified.
    # Try to find a more robust selector by inspecting the Genius page.
    # Example: Look for a div under #lyrics-root that contains all lyrics,
    # possibly with a class name that starts with "Lyrics__Container" or similar.
    # The selector below is a GUESS and needs verification.
    lyrics_block = doc.at_css('div[class*="Lyrics__Container"]') # More robust
# debugger


# You might need to experiment with selectors like:
# lyrics_block = doc.css('[data-lyrics-container="true"]').first
# lyrics_block = doc.xpath("//div[contains(@class, 'Lyrics__Container')]").first
# The old structure used to be something like:
# lyrics_block = doc.css("div.lyrics > p").first # This is likely outdated

# debugger # Stop here to inspect `doc.to_html` and `lyrics_block`
if lyrics_block.present?
  Rails.logger.info "Found a potential lyrics block for Genius ID: #{genius_song_id}"

  cleaned_lyrics_block = lyrics_block.dup

  # --- UPDATED SELECTORS TO REMOVE ---
  # Using [class*="..."] to target the stable part of the class names you provided.
  # These will remove elements whose class attribute CONTAINS the given string.
  selectors_to_remove = [
    'div[class*="LyricsHeader__Container"]',          # Targets elements like LyricsHeader__Container-sc-d6abeb2b-1 fsbvCW
    'div[class*="ContributorsCreditSong__Container"]', # Targets elements like ContributorsCreditSong__Container-sc-3ec5a79c-0 cRdBdF
    'div[class*="Dropdown__Container"]'           # Targets elements like Dropdown__Container-sc-791290da-0 ktShZP
    # You can add other general selectors from the previous example if they are still needed, for example:
    # 'div[class*="Translations"]', # If translations are in a separate container not covered above
    # 'div[class*="Lyrics__Actions"]'  # If action buttons are separate
  ]
  # Note: Assuming these are 'div' elements. If they can be other tags (like 'section'),
  # you might use '*' instead of 'div', e.g., '*[class*="LyricsHeader__Container"]'
  # or list specific tags if known e.g. 'section[class*="LyricsHeader__Container"]'

  Rails.logger.info "Attempting to remove elements with selectors: #{selectors_to_remove.join(', ')}"
  removed_something = false
  selectors_to_remove.each do |selector|
    elements_to_remove = cleaned_lyrics_block.css(selector)
    if elements_to_remove.any?
      Rails.logger.debug "Found #{elements_to_remove.count} element(s) matching selector '#{selector}'. Removing them."
      elements_to_remove.remove
      removed_something = true
    else
      Rails.logger.debug "No elements found matching selector '#{selector}'."
    end
  end

  if removed_something
    Rails.logger.info "Elements removed. Processing cleaned lyrics block."
  else
    Rails.logger.info "No specific elements for removal were found. Processing original block structure."
  end
  # --- END OF UPDATED REMOVAL PART ---

  # Now, process the cleaned_lyrics_block for text
  html_content = cleaned_lyrics_block.inner_html

  processed_html = html_content.gsub(/<br\s*\/?>/i, "\n") # Case insensitive <br>
                              .gsub(/<p\b[^>]*>/i, "")    # Remove opening <p> tags
                              .gsub(/<\/p>/i, "\n\n")      # Replace closing </p> with double newline

  lyrics_text = Nokogiri::HTML.fragment(processed_html).text
  lyrics_text = lyrics_text.gsub(/\[[^\]]*\]/, "")     # Remove bracketed text like [Chorus], [Verse], etc.
                           .gsub(/\n{2,}/, "\n\n")    # Normalize multiple newlines (changed from \n{3,} to \n{2,})
                           .strip                     # Remove leading/trailing whitespace

  if lyrics_text.present?
    Rails.logger.info "Successfully extracted lyrics after cleaning for Genius ID: #{genius_song_id}"
    # For detailed debugging of the final output:
    # Rails.logger.debug "Final Lyrics for #{genius_song_id}: ----\n#{lyrics_text}\n----"
    lyrics_text
  else
    Rails.logger.warn "Lyrics block found and (potentially) cleaned, but no text extracted for URL: #{lyrics_url}."
    # For debugging, you might want to see the HTML of the cleaned block if lyrics_text is empty:
    # Rails.logger.debug "Cleaned block HTML (if lyrics empty): #{cleaned_lyrics_block.to_html.truncate(1000)}"
    nil
  end
else
  Rails.logger.warn "Lyrics block NOT found using selector for URL: #{lyrics_url}. Page HTML sample: #{doc.to_html.truncate(1000)}"
  nil
end

    rescue OpenURI::HTTPError => e
      Rails.logger.error "HTTPError fetching lyrics from #{lyrics_url}: #{e.message}"
      nil
    rescue StandardError => e
      Rails.logger.error "Error fetching or parsing lyrics from #{lyrics_url}: #{e.message} \n#{e.backtrace.join("\n")}"
      nil
    end
  end
end
