class ChatResponseJob < ApplicationJob
  include BroadcastSafely

  SKELETON_ID = "message_skeleton"

  def perform(chat_id, content)
    chat = NatAgent.find(chat_id)
    accumulated = ""

    chat.after_message do |llm_message|
      next if llm_message.role == :user
      next if llm_message.role == :assistant && !llm_message.tool_call?

      record = chat.messages.reload.last
      next unless record

      broadcast_safely do
        record.broadcast_before_to("chat_#{chat_id}",
          target: "#{SKELETON_ID}_#{chat_id}")
      end
    end

    begin
      chat.complete do |chunk|
        next unless chunk.content.present?

        if accumulated.empty?
          broadcast_safely do
            chat.messages.last.broadcast_replace_to("chat_#{chat_id}",
              target: "#{SKELETON_ID}_#{chat_id}")
          end
        end

        accumulated << chunk.content
        chat.messages.last.broadcast_chunk(accumulated)
      end
    rescue StandardError => e
      error_message = chat.messages.create!(role: :assistant, content: "Error: #{e.message}")
      broadcast_safely do
        error_message.broadcast_replace_to("chat_#{chat_id}",
          target: "#{SKELETON_ID}_#{chat_id}")
      end
      return
    end

    if accumulated.empty?
      broadcast_safely do
        chat.messages.where(role: :assistant).last&.broadcast_replace_to("chat_#{chat_id}",
          target: "#{SKELETON_ID}_#{chat_id}")
      end
    end
  end
end
