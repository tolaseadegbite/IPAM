class Employee < ApplicationRecord
  # has_paper_trail

  belongs_to :department
  has_many :devices # History: "What devices does Sarah have?"

  enum :status, { active: 0, on_leave: 1, terminated: 2 }

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :first_name, :last_name, presence: true
  # validates :email, uniqueness: true, allow_blank: true
  validates :phone_number, uniqueness: true, allow_blank: true
  validates :status, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
