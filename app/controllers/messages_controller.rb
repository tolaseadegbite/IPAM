class MessagesController < ApplicationController
  before_action :set_chat

  layout false, only: :index

  def index
    @messages = find_paged_messages

    if @messages.any?
      fresh_when @messages
    else
      head :no_content
    end
  end

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
    @chat = current_user.chats.find(params[:chat_id])
  end

  def find_paged_messages
    if params[:before].present?
      @chat.messages.page_before(@chat.messages.find(params[:before]))
    elsif params[:after].present?
      @chat.messages.page_after(@chat.messages.find(params[:after]))
    else
      @chat.messages.last_page
    end
  end
end
