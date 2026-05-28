Rails.application.routes.draw do
  root to: 'home#index'

  get '/managers', to: 'managers#index', as: :managers
  get '/newest', to: 'thirteen_fs#newest_filings', as: :newest_filings

  get '/manager/:id', to: 'thirteen_fs#manager', as: :manager
  get '/manager/:cik/cusip/:cusip', to: 'thirteen_fs#manager_cusip_history', as: :manager_cusip_history

  get '/13f/:id', to: 'thirteen_fs#holdings_aggregated', as: :thirteen_f
  get '/13f/:id/detailed', to: 'thirteen_fs#holdings_detailed', as: :thirteen_f_detailed
  get '/13f/:external_id/compare/:other_external_id', to: 'thirteen_fs#compare_holdings', as: :thirteen_f_comparison

  get '/cusip/:cusip/:year/:quarter', to: 'thirteen_fs#all_cusip_holders', as: :all_cusip_holders
  get '/cusip/:cusip', to: 'thirteen_fs#cusip_index', as: :cusip_index

  get '/data/autocomplete', to: 'data#autocomplete', as: :autocomplete
  get '/data/13f/:external_id', to: 'data#thirteen_f_data', as: :thirteen_f_data
  get '/data/13f/:external_id/detailed', to: 'data#thirteen_f_detailed_data', as: :thirteen_f_detailed_data
  get '/data/13f/:external_id/compare/:other_external_id', to: 'data#compare_holdings_data', as: :thirteen_f_comparison_data
  get '/data/cusip/:cusip/:year/:quarter', to: 'data#all_cusip_holders_data', as: :all_cusip_holders_data
  get '/data/manager/:cik/cusip/:cusip', to: 'data#manager_cusip_history_data', as: :manager_cusip_history_data

  # ─── New JSON API ──────────────────────────────────────────────
  namespace :api, defaults: { format: :json } do
    get 'healthz', to: 'healthz#show'

    resources :filers, only: [:index, :show], param: :cik, constraints: { cik: /\d{10}/ } do
      resources :filings, only: :index
      get :aum_history, on: :member
      collection do
        get :by_ciks
      end
    end

    resources :filings, only: :show do
      get :holdings,            on: :member
      get :aggregate_holdings,  on: :member
      get 'compare/:other_id',  to: 'filings#compare', on: :member, as: :compare
    end

    resources :cusips, only: :show, param: :cusip, constraints: { cusip: /[A-Z0-9]{9}/ } do
      get :holders, on: :member
      get :history, on: :member
    end

    # v2 citation resolution (T-515)
    resources :chunks, only: :show
    resources :atoms,  only: :show

    # v2 manual document upload (T-540)
    resources :documents, only: :create

    resources :mappings, param: :cusip, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get  :sources
        post 'sync/sec',       to: 'mappings#sync_sec'
        post 'sync/openfigi',  to: 'mappings#sync_openfigi'
        post 'sync/yfinance',  to: 'mappings#sync_yfinance'
        post :import           # multipart CSV
      end
    end

    resources :watchlists

    namespace :ai do
      get  :providers,             to: 'providers#index'
      patch 'providers/:id',       to: 'providers#update',  as: :provider
      post 'providers/:id/test',   to: 'providers#test',    as: :test_provider
      patch 'providers/:id/default_model', to: 'providers#default_model'

      post :chat,        to: 'chat#create'
      post 'chat/stream', to: 'chat#stream'
      post :lab,         to: 'lab#run'
      get  :insights,    to: 'insights#index'
      resources :conversations

      # v2 feedback (T-525)
      post 'messages/:id/feedback', to: 'feedback#message_feedback'
      post 'atoms/:id/correct',     to: 'feedback#atom_correction'
    end

    get :recent_filings, to: 'recent_filings#index'
  end
end
