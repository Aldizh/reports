class SessionsController < ApplicationController
  def new
  end

  def create
  	login = params[:email]
    pw = params[:password]
      if login == 'aldi' and pw == 'alditest'
        session[:current_login] = login
        session[:current_pw] = pw
        session[:authenticated] = true
      end

      if session[:current_login]
        flash[:notice] = "You are successfuly logged in!"
        redirect_to '/dashboard/index'
      else 
        flash[:error] = "Wrong Login or Password!"
        redirect_to '/sessions/new'
      end
  end

  def destroy
    Rails.cache.delete('customer_sel')
    Rails.cache.delete('reseller_sel')
    Rails.cache.delete('carrier_sel')
    Rails.cache.delete('customer_info')
    Rails.cache.delete('carrier_info')
    reset_session
    flash[:notice] = "You are successfuly logged out!"
    redirect_to '/sessions/new'
  end
end
