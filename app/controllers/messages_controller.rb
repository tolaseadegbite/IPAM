class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params.dig(:message, :content)
    if content.present?
      @user_message = @chat.messages.create!(role: :user, content: content)

      ChatResponseJob.perform_later(@chat.id, content)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @chat }
      end
    end
  end

  private

  def set_chat
    @chat = Chat.find(params[:chat_id])
  end
end
