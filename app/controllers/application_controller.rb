class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?

  before_action :set_current_request_details
  before_action :set_current_user_from_session
  before_action :authenticate
  before_action :set_paper_trail_whodunnit

  include Pagy::Backend

  private

  def set_current_user_from_session
    if session_record = Session.find_by_id(cookies.signed[:session_token])
      Current.session = session_record
    end
  end

  def current_user
    Current.user
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate
    unless user_signed_in?
      redirect_to sign_in_path, alert: "You must be signed in to access this page."
    end
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
  end

  def require_sudo
    unless Current.session.sudo?
      redirect_to new_sessions_sudo_path(proceed_to_url: request.original_url)
    end
  end

  def require_admin
    unless Current.user.admin?
      redirect_to root_path, alert: "You are not authorized to access that page."
    end
  end
end
