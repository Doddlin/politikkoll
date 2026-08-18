class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :ensure_session_established
  before_action :set_locale

  private

  # CSP nonces (config/initializers/content_security_policy.rb) are keyed
  # off session.id, which Rails' cookie session store leaves blank until
  # something actually writes to the session — meaning on a visitor's very
  # first pageview, with nothing yet written, the nonce in the response
  # header and the nonce stamped on javascript_importmap_tags' own inline
  # scripts would both come back blank and silently fail to match,
  # breaking the site for every first-time visitor. Force it to exist
  # before anything else runs.
  def ensure_session_established
    session[:established] ||= true
  end

  def set_locale
    I18n.locale = session[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
  end
end
