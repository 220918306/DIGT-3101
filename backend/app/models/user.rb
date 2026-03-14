class User < ApplicationRecord
  has_secure_password

  enum :role, { tenant: "tenant", clerk: "clerk", admin: "admin" }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, :role, presence: true
  validates :password, length: { minimum: 6 }, allow_blank: true

  has_one :tenant, dependent: :destroy

  before_save { self.email = email.downcase }
end
