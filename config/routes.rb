Rails.application.routes.draw do

  scope path: 'ventas' do

  get "/service-worker.js" => "service_worker#service_worker"
  get "/manifest.json" => "service_worker#manifest"



  root 'home#index', as: 'home'


  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  namespace :authentication, path: '', as: '' do
    resources :users, path: '/users' do
      member do
        get :manage_permisos
        patch :update_permisos
      end
    end
    resources :sessions, only: [:new, :create, :destroy], path: '/login', path_names: { new: '/' }
  end

  get '/offline', to: 'static#offline'



  resources :users, only: :show, path: '/user', param: :username, as: 'perfil'


  resources :records, only: [:index], path: '/records' do

  end

  end
end
