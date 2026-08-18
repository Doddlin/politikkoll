class LocalesController < ApplicationController
  def update
    session[:locale] = params[:locale] if I18n.available_locales.map(&:to_s).include?(params[:locale])
    redirect_back fallback_location: root_path
  end
end
