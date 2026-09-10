class NotificationsController < ApplicationController
  def index
    @pagy, @notifications = pagy(current_user.notifications.newest_first)
  end

  def update
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.html { redirect_to notifications_path }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(@notification, partial: "notifications/notification", locals: { notification: @notification }),
          turbo_stream.replace("notification_bell", partial: "notifications/bell", locals: { user: current_user })
        ]
      end
    end
  end
end
