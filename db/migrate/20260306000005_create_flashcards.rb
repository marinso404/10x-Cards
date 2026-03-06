# frozen_string_literal: true

class CreateFlashcards < ActiveRecord::Migration[8.1]
  def change
    create_table :flashcards do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :generation, null: true, foreign_key: { on_delete: :nullify }
      t.string :front, limit: 200, null: false
      t.string :back, limit: 500, null: false
      t.string :source, null: false

      t.timestamps
    end

    # front: 1..200 characters
    add_check_constraint :flashcards,
      "char_length(front) > 0 AND char_length(front) <= 200",
      name: "chk_flashcards_front_length"

    # back: 1..500 characters
    add_check_constraint :flashcards,
      "char_length(back) > 0 AND char_length(back) <= 500",
      name: "chk_flashcards_back_length"

    # source enum values
    add_check_constraint :flashcards,
      "source IN ('manual', 'ai_generated', 'ai_edited')",
      name: "chk_flashcards_source_value"
  end
end
