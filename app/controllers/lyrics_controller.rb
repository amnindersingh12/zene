class LyricsController < ApplicationController
  include GeniusLyricsHelper

  before_action :set_genius_access_token
  before_action :find_song, only: [ :practice ]
  before_action :require_user, only: [ :connect_genius, :genius_callback ]

  def index
    @popular_songs = fetch_and_cache_popular_songs
  end

  def practice
    fetch_and_display_lyrics
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Song not found."
  end

  def search
    @search_results = perform_song_search(params[:query])
  end

  def popular
    redirect_to root_path
  end

  def connect_genius
    redirect_to genius_oauth_authorize_url
  end

  def genius_callback
    handle_genius_oauth_callback
  end

  private

  # --- Genius API Configuration ---
  GENIUS_AUTHORIZE_URL = "https://api.genius.com/oauth/authorize".freeze
  GENIUS_TOKEN_URL = "https://api.genius.com/oauth/token".freeze
  GENIUS_REDIRECT_URI = "http://localhost:3000/auth/genius/callback".freeze

  def set_genius_access_token
    Genius.access_token = ENV["GENIUS_ACCESS_TOKEN"] if ENV["GENIUS_ACCESS_TOKEN"].present?
    # Reduced logging: Only log if token is set
    Rails.logger.info "Genius Access Token set" if Genius.access_token.present?
  end

  # --- Song Retrieval and Display ---
  def find_song
    @song = Song.find(params[:id])
  end

  def fetch_and_display_lyrics
    lyrics = fetch_and_cache_genius_lyrics(@song.genius_id)
      if lyrics.present?
        @song.update(lyrics_html: lyrics)
      else
        flash.now[:alert] = "Failed to fetch lyrics. Please try again."
      end

    render :practice
  end

  # --- Popular Songs ---
  def fetch_and_cache_popular_songs
    Rails.cache.fetch("popular_songs", expires_in: 12.hours) do
      Rails.logger.info "Fetching popular songs (cache miss)"
      Song.order(pyongs_count: :desc).limit(10).map { |song| fetch_song_details_with_lyrics(song) }
    end
  end

  def fetch_song_details_with_lyrics(song)
    unless song.lyrics_html.present?
      lyrics = fetch_and_cache_genius_lyrics(song.genius_id)
      song.update(lyrics_html: lyrics) if lyrics.present?
    end
    fetch_song_art_url(song)
  end

  def fetch_song_art_url(song)
    begin
      genius_song = Genius::Song.find(song.genius_id)
      song.song_art_image_url = genius_song&.resource&.[]("song_art_image_url") if genius_song&.resource&.[]("song_art_image_url").present?
    rescue Genius::Error => e
      Rails.logger.error "Error fetching Genius song details for ID #{song.genius_id}: #{e.message}"
    end
    song
  end

  # --- Song Search ---
  def perform_song_search(query)
    return [] unless query.present?

    genius_results = Genius::Song.search(query)
    genius_results.map do |result|
      Song.find_or_create_by(genius_id: result.id) do |song|
        assign_song_attributes(song, result)
      end
    end
  end

  def assign_song_attributes(song, result)
    song.title = result.title
    song.artist = result.primary_artist.name
    song.url = result.url
    song.lyrics = result.resource["url"] # Consider renaming
    song.pyongs_count = result.pyongs_count
    song.description = result.description
    song.song_art_image_url = result.resource["song_art_image_url"]
  end

  # --- Genius OAuth ---
  def require_user
    unless current_user
      flash[:alert] = "You need to be logged in to connect your Genius account."
      redirect_to login_path
    end
  end

  def genius_oauth_authorize_url
    state = SecureRandom.hex(16)
    session[:oauth_state] = state

    authorize_params = {
      client_id: ENV["GENIUS_CLIENT_ID"],
      redirect_uri: genius_callback_url,
      response_type: "code",
      scope: "me",
      state: state
    }
    "#{GENIUS_AUTHORIZE_URL}?#{authorize_params.to_query}"
  end

  def handle_genius_oauth_callback
    unless params[:state].present? && params[:state] == session[:oauth_state]
      flash[:error] = "Invalid OAuth state."
      redirect_to root_path and return
    end
    session.delete(:oauth_state)

    if params[:error].present?
      flash[:error] = "Genius authorization failed: #{params[:error_description] || params[:error]}"
      redirect_to root_path and return
    end

    exchange_code_for_token(params[:code])
  end

  def exchange_code_for_token(authorization_code)
    conn = Faraday.new(url: GENIUS_TOKEN_URL) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = conn.post do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = {
        grant_type: "authorization_code",
        code: authorization_code,
        client_id: ENV["GENIUS_CLIENT_ID"],
        client_secret: ENV["GENIUS_CLIENT_SECRET"],
        redirect_uri: genius_callback_url
      }
    end

    process_token_response(response)
  rescue Faraday::Error => e
    flash[:error] = "Network error during token exchange: #{e.message}"
    redirect_to root_path
  rescue JSON::ParserError
    flash[:error] = "Invalid JSON response from Genius token endpoint."
    redirect_to root_path
  end

  def process_token_response(response)
    if response.success?
      token_data = JSON.parse(response.body)
      current_user.update(
        genius_access_token: token_data["access_token"],
        genius_refresh_token: token_data["refresh_token"]
      )
      flash[:notice] = "Successfully connected your Genius account!"
      redirect_to root_path
    else
      flash[:error] = "Failed to exchange authorization code for token: #{response.status} - #{response.body}"
      redirect_to root_path
    end
  end
end
