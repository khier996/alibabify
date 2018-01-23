Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".
  require 'sidekiq/web'

  mount ShopifyApp::Engine, at: '/'

  mount Sidekiq::Web => '/sidekiq'

  root :to => 'admin/dashboard#index'

  get '/bulk_upload', to: 'admin/dashboard#bulk_upload'
  post '/parse_pages', to: 'admin/dashboard#parse_pages'
  get '/update_products', to: 'admin/dashboard#update_products'

  get '/dictionary_lookup', to: 'admin/dashboard#dictionary_lookup'
  get '/dictionary_complete', to: 'dictionary#complete'
  post '/edit_dictionary_entry', to: 'dictionary#edit_entry'

  # the ProxyController will pick up ApplicationProxy requests
  # and forward valid ones on to the pages#show action
  get 'proxy' => 'proxy#index'

  # scope all admin controllers,
  # views and models within admin namespace
  namespace :admin do
    resources :dashboard
  end

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
