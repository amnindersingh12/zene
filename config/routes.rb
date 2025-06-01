Rails.application.routes.draw do
  root 'lyrics#index'

  # Display a specific song's lyrics for practice
  get '/practice/:id', to: 'lyrics#practice', as: 'practice_lyric'

  # Search for songs
  get '/search', to: 'lyrics#search', as: 'search_lyrics'

  # Display popular songs (redirects to root in the controller)
  get '/popular', to: 'lyrics#popular', as: 'popular_lyrics' # Added an 's' for clarity

  # OAuth Routes for Genius API authentication
  get '/auth/genius', to: 'lyrics#connect_genius', as: :connect_genius
  get '/auth/genius/callback', to: 'lyrics#genius_callback', as: :genius_callback
end
