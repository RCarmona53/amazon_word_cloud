Rails.application.routes.draw do
  get '/products/word_cloud', to: 'products#word_cloud'
end
