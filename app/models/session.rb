class Session < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true
  # Możesz dodać walidacje dla ip_address i user_agent jeśli wymagane
end
