class LyricsController < ApplicationController
  # Constants for Genius API and OAuth
  GENIUS_AUTHORIZE_URL = "https://api.genius.com/oauth/authorize".freeze
  GENIUS_TOKEN_URL = "https://api.genius.com/oauth/token".freeze
  GENIUS_REDIRECT_URI = "http://localhost:3000/auth/genius/callback".freeze # Update this!

  # Set the Genius access token before any action is executed
  before_action :set_genius_access_token

  before_action :find_song, only: [:practice]
  before_action :require_user, only: [:connect_genius, :genius_callback] # Example: Require user to be logged in for OAuth

  def index
    @popular_songs = Song.order(pyongs_count: :desc).limit(10)
    # Consider fetching popular songs from Genius API if your DB is empty
  end

  def practice
    @song = Song.find(params[:id])
    unless @song.lyrics.present?
      genius_song = Genius::Song.find(@song.genius_id)
      if genius_song&.lyrics.present?
        @song.update(lyrics: genius_song.lyrics)
      else
        redirect_to root_path, alert: 'Failed to fetch lyrics or lyrics are empty.'
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Song not found.'
  end

  def search
    if params[:query].present?
      genius_results = Genius::Song.search(params[:query])
      @search_results = genius_results.map do |result|
        song = Song.find_or_create_by(genius_id: result.id) do |s|
          s.title = result.title
          s.artist = result.primary_artist.name
          s.url = result.url
          s.pyongs_count = result.pyongs_count
          s.description = result.description
        end
        song
      end
    else
      @search_results = []
    end
  end

  def popular
    redirect_to root_path
  end

  def connect_genius
    # Initiate the Genius OAuth flow
    state = SecureRandom.hex(16)
    session[:oauth_state] = state

    authorize_params = {
      client_id: ENV['GENIUS_CLIENT_ID'],
      redirect_uri: genius_callback_url, # Use the Rails path helper
      response_type: 'code',
      scope: 'me',
      state: state
    }

    redirect_to "#{GENIUS_AUTHORIZE_URL}?#{authorize_params.to_query}", allow_other_host: true
  end

  def genius_callback
    # Handle the callback from Genius
    if params[:state].blank? || params[:state] != session[:oauth_state]
      flash[:error] = "Invalid OAuth state."
      redirect_to root_path and return
    end

    session.delete(:oauth_state)

    if params[:error].present?
      flash[:error] = "Genius authorization failed: #{params[:error_description] || params[:error]}"
      redirect_to root_path and return
    end

    authorization_code = params[:code]

    conn = Faraday.new(url: GENIUS_TOKEN_URL) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end

    response = conn.post do |req|
      req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      req.body = {
        grant_type: 'authorization_code',
        code: authorization_code,
        client_id: ENV['GENIUS_CLIENT_ID'],
        client_secret: ENV['GENIUS_CLIENT_SECRET'],
        redirect_uri: genius_callback_url # Use the Rails path helper
      }
    end

    if response.success?
      token_data = JSON.parse(response.body)
      access_token = token_data['access_token']
      refresh_token = token_data['refresh_token']

      current_user.update(
        genius_access_token: access_token,
        genius_refresh_token: refresh_token
      )
      flash[:notice] = "Successfully connected your Genius account!"
      redirect_to root_path # Or a user profile page
    else
      flash[:error] = "Failed to exchange authorization code for token: #{response.status} - #{response.body}"
      redirect_to root_path
    end
  rescue Faraday::Error => e
    flash[:error] = "Network error during token exchange: #{e.message}"
    redirect_to root_path
  rescue JSON::ParserError
    flash[:error] = "Invalid JSON response from Genius token endpoint."
    redirect_to root_path
  end

  private

  def set_genius_access_token
    Genius.access_token = ENV['GENIUS_ACCESS_TOKEN'] if ENV['GENIUS_ACCESS_TOKEN'].present?
    Rails.logger.info "Genius Access Token set in controller: #{Genius.access_token.inspect}"
  end

  def find_song
    @song = Song.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Song not found.'
  end

  def require_user
    unless current_user # Replace with your actual authentication logic
      flash[:alert] = "You need to be logged in to connect your Genius account."
      redirect_to login_path # Replace with your login path
    end
  end
end
