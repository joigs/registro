Rails.application.config.session_store :cookie_store,
                                       key: '_ventas_session',
                                       path: '/ventas',
                                       same_site: :lax