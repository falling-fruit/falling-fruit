FallingfruitWebapp::Application.routes.draw do

  devise_for :users
  resources :users do
    member do
      get 'switch'
    end
  end

  resources :routes do
    collection do
      post 'multiupdate'
    end
    member do
      get 'reposition'
    end
  end

  resources :locations do
    member do
      get 'enroute'
    end
    collection do
      get 'home'
      get 'import'
      post 'import'
      get 'data'
      get 'embed'
    end
  end

  resources :types do
    member do
      get 'merge'
    end
    collection do
      get 'grow'
      get 'merge'
    end
  end

  resources :regions

  match 'about' => 'pages#about'
  match 'datasets' => 'pages#datasets'
  match 'sharing' => 'pages#sharing'
  match 'press' => 'pages#press'
  match 'data' => 'pages#data'
  match 'dumpsters' => 'locations#freegan_index'
  match 'freegan' => 'locations#freegan_index'
  match 'imports/bibliography' => 'pages#datasets'
  match 'home' => 'locations#home'
  
  # Replaced by pages#datasets (unused, but kept for posterity)
  match 'maps' => 'pages#datasets'
  match 'inventories' => 'pages#datasets'

  # Still used by /imports/show. Consider redirecting to /datasets.
  resources :imports

  resources :changes

  resources :observations do
    member do
      get 'delete_photo'
    end
  end

  resources :problems

  match 'locations/:id/infobox' => 'locations#infobox'

  namespace :api do
    resources :locations do
      member do
        get 'reviews'
      end
      collection do
        get 'cluster'
        get 'markers'
        get 'marker'
        get 'cluster_types'
        get 'mine'
        get 'favorite'
        get 'nearby'
      end
    end

  end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'locations#index'

  # See how all your routes lay out with "rake routes"
  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
