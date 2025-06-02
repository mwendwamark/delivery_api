class CustomerProfile < ApplicationRecord
  belongs_to :user

  validates :date_of_birth, presence: true
  validate :must_be_18_or_older

  def age
    return nil unless date_of_birth
    now = Time.current.to_date
    now.year - date_of_birth.year - (date_of_birth.change(year: now.year) > now ? 1 : 0)
  end

  def age_verified?
    age.present? && age >= 18
  end

  private

  def must_be_18_or_older
    return unless date_of_birth.present?
    if age < 18
      errors.add(:date_of_birth, "must be at least 18 years old")
    end
  end
end
