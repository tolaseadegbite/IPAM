class Authentications::EventsController < ApplicationController
  def index
    @pagy, @events = pagy(Current.user.events.order(created_at: :desc))
  end
end
