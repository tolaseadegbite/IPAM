class ApiToken < ApplicationRecord
  belongs_to :user

  validates :name, presence: true

  # Issues a token, returning [record, raw_secret]. The raw secret is
  # shown once and never stored — only its digest hits the database.
  def self.issue!(user:, name:, expires_at: nil)
    raw = SecureRandom.hex(32)
    record = create!(
      user: user,
      name: name,
      token_digest: Digest::SHA256.hexdigest(raw),
      prefix: raw.first(8),
      expires_at: expires_at
    )
    [ record, raw ]
  end

  def expired?
    expires_at&.past? || false
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "created_at", "expires_at", "last_used_at" ]
  end
end
