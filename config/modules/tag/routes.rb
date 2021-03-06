ZomekiCMS::Application.routes.draw do
  mod = 'tag'

  ## script
  get "/_script/#{mod}/script/tags/publish" => "#{mod}/script/tags#publish"

  ## admin
  scope "#{ZomekiCMS::ADMIN_URL_PREFIX}/#{mod}/c:concept", :module => mod, :as => mod do
    resources :content_base,
      :controller => 'admin/content/base'

    resources :content_settings, :only => [:index, :show, :edit, :update],
      :controller => 'admin/content/settings',
      :path       => ':content/content_settings'

    ## contents
    resources :tags, :only => [:index],
      :controller => 'admin/tags',
      :path       => ':content/tags'

    ## nodes
    resources :node_tags,
      :controller => 'admin/node/tags',
      :path       => ':parent/node_tags'

    ## pieces
    resources :piece_tags,
      :controller => 'admin/piece/tags'
  end

  ## public
  scope "_public/#{mod}", :module => mod, :as => '' do
    get 'node_tags(/index.:format)' => 'public/node/tags#index'
    get 'node_tags/:word(/index.:format)' => 'public/node/tags#show'
  end
end
