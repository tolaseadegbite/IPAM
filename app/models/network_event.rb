class NetworkEvent < ApplicationRecord
  belongs_to :device, optional: true

  enum :kind, { info: 0, drift: 1, outage: 2, security: 3 }, prefix: true

  # Optional: Clean up old logs automatically
  scope :recent, -> { order(created_at: :desc).limit(20) }
end
