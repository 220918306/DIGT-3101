class Letter < ApplicationRecord
  belongs_to :tenant
  belongs_to :lease

  enum :status, { sent: "sent", signed: "signed" }

  validates :letter_type, :status, :subject, :body, presence: true
end
