# frozen_string_literal: true

class CreateGenerationErrorLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :generation_error_logs do |t|
      t.references :generation, null: false, foreign_key: { on_delete: :cascade }
      t.string :error_code, null: false
      t.text :error_message, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end
  end
end
