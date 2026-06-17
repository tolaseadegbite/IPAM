module BroadcastSafely
  extend ActiveSupport::Concern

  private

  def broadcast_safely
    retries = 0
    begin
      yield
    rescue ActiveRecord::StatementInvalid, ActiveRecord::StatementTimeout => e
      retries += 1
      if retries < 3
        sleep 0.1 * retries
        retry
      end
      Rails.logger.error("Broadcast failed after #{retries} retries: #{e.message}")
    end
  end
end
