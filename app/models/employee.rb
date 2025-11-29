class Employee < ApplicationRecord
  # has_paper_trail

  belongs_to :department
  has_many :devices # History: "What devices does Sarah have?"

  enum :status, { active: 0, on_leave: 1, terminated: 2 }

  validates :first_name, :last_name, presence: true
  validates :status, presence: true

  def full_name
    "#{first_name} #{last_name}"
  end

  ransacker :full_name do |parent|
    Arel::Nodes::NamedFunction.new("CONCAT_WS", [
      Arel::Nodes.build_quoted(" "), parent.table[:first_name], parent.table[:last_name]
    ])
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[ id full_name status created_at updated_at ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "department", "devices" ]
  end
end
