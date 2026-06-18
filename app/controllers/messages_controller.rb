class MessagesController < ApplicationController
  before_action :set_chat

  def create
    content = params.dig(:message, :content)
    files = params[:attachments]

    if content.present? || files.present?
      @user_message = @chat.messages.create!(role: :user, content: content || "")

      attach_files(@user_message, files) if files.present?

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

  def attach_files(message, files)
    files.each do |file|
      message.attachments.attach(file)
    end
  end
end
