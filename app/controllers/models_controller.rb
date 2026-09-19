class ModelsController < ApplicationController
  before_action :require_admin, only: [ :refresh ]

  def index
    @models = available_chat_models
  end

  def show
    @model = RubyLLM.models.find(params[:id])
  end

  def refresh
    RubyLLM.models.refresh
    redirect_back_or_to models_path, notice: "Models refreshed successfully"
  end
end
