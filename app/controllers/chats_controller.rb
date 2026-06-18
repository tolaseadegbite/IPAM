class ChatsController < ApplicationController
  before_action :set_chat, only: [ :destroy ]
  before_action :set_chat_with_agent, only: [ :show ]

  def index
    records = Chat.includes(:messages, :user).order(updated_at: :desc)
    @pagy, @chats = pagy(records, limit: 20)
  end

  def new
    @chat = Chat.new
    @selected_model = params[:model]
    @chat_models = available_chat_models
  end

  def create
    prompt = params.dig(:chat, :prompt)
    attachment_ids = params.dig(:message, :attachment_ids)

    if prompt.present? || attachment_ids.present?
      selected_model = params.dig(:chat, :model).presence
      opts = { user: current_user }
      opts[:model] = selected_model if selected_model
      @chat = NatAgent.create!(**opts)

      message = @chat.messages.create!(role: :user, content: prompt || "")

      message.attachments.attach(attachment_ids) if attachment_ids.present?

      ChatResponseJob.perform_later(@chat.id, prompt || "")

      redirect_to @chat, notice: "Chat was successfully created."
    end
  end

  def show
    @message = @chat.messages.build
  end

  def destroy
    @chat.destroy!
    redirect_to chats_path, notice: "Chat was successfully destroyed.", status: :see_other
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end

  def set_chat_with_agent
    @chat = NatAgent.find(params[:id])
  end
end
