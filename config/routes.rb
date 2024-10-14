Rails.application.routes.draw do
  post '', to: 'products#create'
end
