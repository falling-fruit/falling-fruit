FallingfruitWebapp::Application.routes.draw do

  devise_for :users
  resources :users

  resources :routes do
    collection do
      post 'multiupdate'
    end
  end

  resources :locations do
    member do
      get 'enroute'
    end
    collection do
      get 'import'
      post 'import'
      get 'cluster'
      get 'markers'
      get 'marker'
      get 'cluster_types'
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
  match 'data' => 'pages#data'
  match 'press' => 'pages#press'
  match 'maps' => 'pages#maps'
  match 'inventories' => 'pages#inventories'
  match 'sharing' => 'pages#sharing'

  resources :imports do
    collection do
      get 'bibliography'
    end
  end

  resources :changes

  resources :observations do
    member do
      get 'delete_photo'
    end
  end

  resources :problems

  match 'locations/:id/infobox' => 'locations#infobox'

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
