# frozen_string_literal: true

class CreateGenerations < ActiveRecord::Migration[8.1]
  def change
    create_table :generations do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.text :source_text, null: false
      t.string :source_text_hash, null: false
      t.integer :source_text_length, null: false
      t.string :model, null: false
      t.integer :generated_count, null: false, default: 0
      t.integer :accepted_unedited_count, null: false, default: 0
      t.integer :accepted_edited_count, null: false, default: 0
      t.integer :generation_duration, null: false

      t.timestamps
    end

    add_index :generations, %i[user_id source_text_hash], unique: true, name: "index_generations_on_user_id_and_source_text_hash"

    # source_text length must be between 1000 and 10000 characters
    add_check_constraint :generations,
      "char_length(source_text) BETWEEN 1000 AND 10000",
      name: "chk_generations_source_text_length"
  end
end
