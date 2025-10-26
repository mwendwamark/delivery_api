class User < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Associations
  has_one :delivery_person_profile
  has_one :customer_profile
  has_one :admin_profile
  has_many :addresses
  has_many :orders
  has_one :cart

  # Validations - IMPORTANT: Only validate date_of_birth for customers
  validates :date_of_birth, presence: { message: "is required" }, if: :customer?
  validate :must_be_18_or_older, if: :date_of_birth_present?

  # Role helper methods (since we're not using enum)
  def customer?
    role == 0
  end

  def admin?
    role == 1
  end

  def delivery_person?
    role == 2
  end

  def age
    return nil unless date_of_birth.present?
    now = Time.current.to_date
    now.year - date_of_birth.year - (date_of_birth.change(year: now.year) > now ? 1 : 0)
  end

  def age_verified?
    return true unless customer? # Non-customers don't need age verification
    age.present? && age >= 18
  end

  private

  def date_of_birth_present?
    date_of_birth.present?
  end

  def must_be_18_or_older
    return unless date_of_birth.present?
    
    calculated_age = age
    if calculated_age.nil? || calculated_age < 18
      errors.add(:date_of_birth, "You must be at least 18 years old to register")
    end
  end
end