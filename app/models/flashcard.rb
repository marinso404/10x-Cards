

class Flashcard < ApplicationRecord
  belongs_to :user
  belongs_to :generation, optional: true

  enum :source, {
    manual: 'manual',
    ai_generated: 'ai_generated',
    ai_edited: 'ai_edited'
  }, prefix: true

  validates :front, presence: true, length: { in: 1..200 }
  validates :back, presence: true, length: { in: 1..500 }
  validates :source, presence: true, inclusion: { in: sources.keys }

  scope :recent, -> { order(created_at: :desc) }
  scope :paged, ->(page = 1) { recent.limit(20).offset((page.to_i - 1) * 20) }
end
