class CustomerProfile < ApplicationRecord
  belongs_to :user

  delegate :age, :age_verified?, :date_of_birth, to: :user
end
