class User < ApplicationRecord
  has_secure_password

  acts_as_paranoid

  def self.ransackable_attributes(auth_object = nil)
    [
      "username",
      "created_at",
      "updated_at"
    ]
  end



  validates :username, presence: true, uniqueness: true,
            length: { in: 3..15 },
            format: {with: /\A[a-z0-9A-Z]+\z/, message: "Solo se permiten letras y numeros"}
  validates :password_digest, length: { minimum: 6 }





  has_many :user_permisos, dependent: :destroy
  has_many :permisos, through: :user_permisos








end
