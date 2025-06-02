class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Remove or comment out the enum line!
  # enum role: { customer: 0, admin: 1, delivery_person: 2 }

  # Optional: Add helper methods for roles
  def customer?
    role == 0
  end

  def admin?
    role == 1
  end

  def delivery_person?
    role == 2
  end

  has_one :delivery_person_profile
  has_one :customer_profile
  has_one :admin_profile
  has_many :addresses
  has_many :orders
  has_one :cart
end
