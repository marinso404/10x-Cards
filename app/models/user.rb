
class User < ApplicationRecord
  has_many :generations, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :flashcards, dependent: :destroy

  validates :email_address, presence: true, uniqueness: true
  has_secure_password validations: false

  # OAuth: provider + uid
  validates :provider, uniqueness: { scope: :uid }, allow_nil: true

  # I18n dla komunikatów
  # validates :first_name, presence: true

  # Hard delete (RODO)
  def destroy!
    transaction do
      flashcards.delete_all
      generations.delete_all
      sessions.delete_all
      super
    end
  end
end
