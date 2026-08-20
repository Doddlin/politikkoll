Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :chat, only: [ :new, :create, :destroy ]
  resources :documents, only: [ :index, :show ]
  resource :geography, only: [ :show ], controller: "geography"
  resource :insights, only: [ :show ], controller: "insights"
  get "locale/:locale", to: "locales#update", as: :set_locale, constraints: { locale: /sv|en/ }
  get "sitemap.xml", to: "sitemap#show", defaults: { format: "xml" }
  get "disclaimer", to: "pages#disclaimer"
  get "how-it-works", to: "pages#how_it_works"
  get "status", to: "pages#status"

  # Defines the root path route ("/")
  root "home#index"
end
