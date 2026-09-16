class HomeController < ApplicationController
  def index
    @api_tokens = Current.user.api_tokens.order(created_at: :desc)
  end
end
