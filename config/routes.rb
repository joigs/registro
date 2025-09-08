Rails.application.routes.draw do

  scope path: 'ventas' do

    get "service-worker.js", to: "service_worker#service_worker", defaults: { format: :js }

    get "manifest.json",
        to: "service_worker#manifest",
        defaults: { format: :json }

    root 'home#index', as: 'home'



    scope :pausa, module: :pausa, as: :pausa do
      get "manifest.json",     to: "service_worker#manifest",      defaults: { format: :json }
      get "service-worker.js", to: "service_worker#service_worker", defaults: { format: :js }
      root "home#index"
      namespace :api, defaults: { format: :json } do
        namespace :v1 do
          post "login", to: "sessions#create"

          resources :app_users do
            collection do
              get :pending
              get :me
            end
            member do
              patch :approve
              patch :push_token
              patch :active, to: "app_users#set_active"
            end
          end
          post :login, to: "sessions#create"
          resources :pause_windows, param: :id, only: [:index, :update]

          resources :daily_logs, only: [] do
            collection do
              get  :today
              patch :mark
            end
          end

          # recordatorios/notificaciones
          resources :reminders, only: [] do
            collection do
              post :trigger
              post :opened
            end
          end

          # reportes
          resources :reports, only: [] do
            collection do
              get :pausas
            end
          end

        end
      end

    end




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


    resources :records, only: [:index], path: '/records' do

    end





  end


end
