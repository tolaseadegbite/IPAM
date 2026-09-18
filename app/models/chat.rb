class Chat < ApplicationRecord
  acts_as_chat
  belongs_to :user

  enum :mode, { plan: "plan", build: "build" }, suffix: true
end
