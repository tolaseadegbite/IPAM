class ChatsController < ApplicationController
  before_action :set_chat, only: %i[update destroy]
  before_action :set_chat_with_agent, only: [ :show ]

  def index
    records = current_user.chats.includes(:messages, :user).order(updated_at: :desc)
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

      # Plan is the database default; only build needs an explicit flip.
      # Unknown values fall through to plan, never raise.
      requested_mode = params.dig(:chat, :mode)
      @chat.update!(mode: :build) if requested_mode == "build"

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

  # Plan/Build mode switch. Only :mode is permitted, and unknown values
  # bounce back instead of raising on the enum.
  def update
    unless Chat.modes.key?(chat_params[:mode])
      redirect_to @chat, alert: "Unknown mode."
      return
    end

    @chat.update!(chat_params)
    # 303 so fetch/XHR clients follow with GET. A 302 would preserve the
    # PATCH across the redirect and loop (browsers only rewrite POST to GET).
    redirect_to @chat, notice: "Switched to #{@chat.mode} mode.", status: :see_other
  end

  private

  def chat_params
    params.require(:chat).permit(:mode)
  end

  def set_chat
    @chat = current_user.chats.find(params[:id])
  end

  def set_chat_with_agent
    current_user.chats.find(params[:id])
    @chat = NatAgent.find(params[:id])
  end
end
