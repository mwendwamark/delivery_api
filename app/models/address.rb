class Address < ApplicationRecord
  belongs_to :user
  has_many :orders

  # Validations
  validates :user, presence: true
  validates :location, presence: true
  validates :street_address, presence: true
  validates :recipient_name, presence: true, if: -> { is_manual? }
  validates :recipient_phone, presence: true, if: -> { is_manual? }
  
  # Scopes
  scope :saved_addresses, -> { where(is_manual: false).or(where(is_manual: nil)) }
  scope :manual_addresses, -> { where(is_manual: true) }
  
  # Class method to create a manual address
  def self.create_manual_address(user, params)
    create(
      user: user,
      is_manual: true,
      location: params[:location],
      street_address: params[:street_address],
      latitude: params[:latitude],
      longitude: params[:longitude],
      recipient_name: params[:recipient_name],
      recipient_phone: params[:recipient_phone]
    )
  end
  
  # Instance method to check if this is a manual address
  def manual_address?
    is_manual == true
  end
  
  # Format the address for display
  def full_address
    [street_address, location].compact.join(', ')
  end
end
