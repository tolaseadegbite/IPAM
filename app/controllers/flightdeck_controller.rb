class FlightdeckController < ActionController::Base
  before_action :set_current_user_from_session
  before_action :require_admin

  private

  def set_current_user_from_session
    if session_record = Session.find_by_id(cookies.signed[:session_token])
      Current.session = session_record
    end
  end

  def require_admin
    if Current.user.nil?
      redirect_to Rails.application.routes.url_helpers.sign_in_path,
        alert: "You must be signed in to access this page."
    elsif !Current.user.admin?
      redirect_to Rails.application.routes.url_helpers.root_path,
        alert: "You are not authorized to access that page."
    end
  end
end
