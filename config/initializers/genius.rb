if ENV['GENIUS_ACCESS_TOKEN'].present?
  Genius.access_token = ENV['GENIUS_ACCESS_TOKEN']
  Rails.logger.info "Genius gem configured with access token."
else
  Rails.logger.warn "GENIUS_ACCESS_TOKEN environment variable is not set. Genius API calls may fail."
end
