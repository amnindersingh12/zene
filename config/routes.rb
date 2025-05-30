
Rails.application.routes.draw do
  root 'lyrics#index'
  get '/practice/:id', to: 'lyrics#practice', as: 'practice_lyric'
  get '/search', to: 'lyrics#search'
  get '/popular', to: 'lyrics#popular'

  # OAuth Routes
  get '/auth/genius', to: 'lyrics#connect_genius', as: :connect_genius
  get '/auth/genius/callback', to: 'lyrics#genius_callback', as: :genius_callback
end
