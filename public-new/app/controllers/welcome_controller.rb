class WelcomeController < ApplicationController
  def show
    @page_title = "Welcome! A New Day Dawns!"
    render  :layout => 'layouts/public_app'
  end
end
