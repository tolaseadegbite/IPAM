class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  after_create :touch_chat

  def broadcast_chunk(content)
    html = ApplicationController.helpers.render_markdown(content.to_s)
    broadcast_update_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      content: html
  rescue ActiveRecord::StatementInvalid, ActiveRecord::StatementTimeout => e
    retries ||= 0
    retries += 1
    if retries < 3
      sleep 0.1
      retry
    end
    Rails.logger.error("ChatResponseJob: failed to broadcast chunk after #{retries} retries: #{e.message}")
  end

  private

  def touch_chat
    chat.touch
  end
end
