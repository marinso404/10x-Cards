
class Generation < ApplicationRecord
  belongs_to :user
  has_many :flashcards, dependent: :nullify
  has_many :generation_error_logs, dependent: :destroy

  validates :user_id, presence: true
  validates :source_text, presence: true, length: { in: 1000..10000 }
  validates :source_text_hash, presence: true
  validates :source_text_length, presence: true
  validates :model, presence: true
  validates :generation_duration, presence: true

  # Unikalność hash dla usera
  validates :source_text_hash, uniqueness: { scope: :user_id }

  before_validation :set_source_text_hash_and_length

  private

  def set_source_text_hash_and_length
    return unless source_text.present?
    self.source_text_hash = Digest::SHA256.hexdigest(source_text)
    self.source_text_length = source_text.length
  end
end
