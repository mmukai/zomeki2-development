ZomekiCMS::Application.routes.draw do
  mod = "sys"

  ## script
  get "/_script/#{mod}/run/*path" => "#{mod}/script/runner#run"

  ## admin
  scope "#{ZomekiCMS::ADMIN_URL_PREFIX}/#{mod}", :module => mod, :as => mod do
    get "tests" => "admin/tests#index",
      :as => :tests
    match "tests_mail" => "admin/tests/mail#index",
      :as => :tests_mail, via: [:get, :post]
    match "tests_link_check" => "admin/tests/link_check#index",
      :as => :tests_link_check, via: [:get, :post]

    resources :settings,
      :controller  => "admin/settings"
    resources :maintenances,
      :controller  => "admin/maintenances"
    resources :messages,
      :controller  => "admin/messages"
    resources :languages,
      :controller  => "admin/languages"
    resources :ldap_groups,
      :controller  => "admin/ldap_groups",
      :path        => ":parent/ldap_groups"
    resources :ldap_users,
      :controller  => "admin/ldap_users",
      :path        => ":parent/ldap_users"
    resources :ldap_synchros,
      :controller  => "admin/ldap_synchros" do
        member do
          get  :synchronize
          post :synchronize
        end
      end
    resources :users,
      :controller  => "admin/users"
    resources :groups,
      :controller  => "admin/groups",
      :path        => ":parent/groups"
    resources :group_users,
      :controller  => "admin/group_users",
      :path        => ":parent/group_users"
    resources :export_groups,
      :controller  => "admin/groups/export" do
        collection do
          get  :export
          post :export
        end
      end
    resources :import_groups,
      :controller  => "admin/groups/import" do
        collection do
          get  :import
          post :import
        end
      end
    resources :role_names,
      :controller  => "admin/role_names"
    resources :object_privileges,
      :controller  => "admin/object_privileges",
      :path        => ":parent/object_privileges"
    resources :inline_files,
      :controller  => "admin/inline/files",
      :path        => ":parent/inline_files" do
        member do
          get :download
        end
      end
    resources :storage_files,
      :controller => "admin/storage_files",
      :path       => "storage_files(/*path)",
      :format     => false
    resources :transferable_files,
      :controller  => "admin/transferable_files" do
        collection do
          get  :refresh
          post :transfer_all
        end
      end
    resources :transferred_files,
      :controller  => "admin/transferred_files"
    resources :operation_logs,
      :controller => "admin/operation_logs"
    resources :processes,
      :controller  => "admin/processes"
  end

  get "#{ZomekiCMS::ADMIN_URL_PREFIX}/#{mod}/:parent/inline_files/files/:name.:format" => 'sys/admin/inline/files#download'
end
