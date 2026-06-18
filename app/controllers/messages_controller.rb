class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params.dig(:message, :content)
    attachment_ids = params.dig(:message, :attachment_ids)

    if content.present? || attachment_ids.present?
      @user_message = @chat.messages.create!(role: :user, content: content || "")

      @user_message.attachments.attach(attachment_ids) if attachment_ids.present?

      ChatResponseJob.perform_later(@chat.id, content || "")

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
