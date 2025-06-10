class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Remove or comment out the enum line!
  # enum role: { customer: 0, admin: 1, delivery_person: 2 }

  # Optional: Add helper methods for roles
  validates :date_of_birth, presence: true, if: :customer?
  validate :must_be_18_or_older, if: :date_of_birth_present?

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

  def age
    return nil unless date_of_birth
    now = Time.current.to_date
    now.year - date_of_birth.year - (date_of_birth.change(year: now.year) > now ? 1 : 0)
  end

  def age_verified?
    age.present? && age >= 18
  end

  private

  def date_of_birth_present?
    date_of_birth.present?
  end

  def must_be_18_or_older
    return unless date_of_birth.present?
    if age < 18
      errors.add(:date_of_birth, "must be at least 18 years old")
    end
  end
end
