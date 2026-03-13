class GenerationErrorLog < ApplicationRecord
  belongs_to :generation

  validates :generation_id, presence: true
  validates :error_code, presence: true
  validates :error_message, presence: true
  validates :occurred_at, presence: true
end
