Rails.application.routes.draw do



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




  resources :users, only: :show, path: '/user', param: :username, as: 'perfil'


  resources :records, only: [:index, :show], path: '/records' do
    collection do
      get :export_excel
    end
  end
  resources :movils, only: [:index, :show], path: '/movils'
  resources :evaluacions, only: [:index, :show], path: '/evaluacions' do
    collection do
      get :export_excel
    end
  end

end
