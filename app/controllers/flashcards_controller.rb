# frozen_string_literal: true

class FlashcardsController < ApplicationController
  before_action :authenticate_user!

  # POST /flashcards
  def create
    items = flashcards_params

    if items.blank?
      return render_error(
        code: 'invalid_request',
        message: I18n.t('api.flashcards.errors.empty'),
        status: :bad_request
      )
    end

    flashcards = []
    validation_error = nil

    ActiveRecord::Base.transaction do
      items.each do |item|
        flashcard = current_user.flashcards.build(
          front: item[:front].to_s.strip,
          back: item[:back].to_s.strip,
          source: item[:source].to_s,
          generation_id: item[:generation_id]
        )

        unless flashcard.valid?
          validation_error = flashcard.errors.messages
          raise ActiveRecord::Rollback
        end

        flashcard.save!
        flashcards << flashcard
      end

      update_generation_counts(flashcards) if flashcards.any?
    end

    if validation_error
      return render json: {
        error: {
          code: 'invalid_request',
          message: I18n.t('api.flashcards.errors.validation_failed'),
          details: validation_error
        }
      }, status: :unprocessable_entity
    end

    render json: {
      data: {
        created_flashcards: flashcards.map { |f|
          { id: f.id, source: f.source, generation_id: f.generation_id }
        },
        count: flashcards.size
      }
    }, status: :created
  rescue ArgumentError => e
    render json: {
      error: {
        code: 'invalid_request',
        message: e.message
      }
    }, status: :unprocessable_entity
  end

  private

  def flashcards_params
    params.permit(flashcards: [ :front, :back, :source, :generation_id ])
          .fetch(:flashcards, [])
  end

  def update_generation_counts(flashcards)
    generation_id = flashcards.first.generation_id
    return unless generation_id

    generation = Generation.find_by(id: generation_id, user_id: current_user.id)
    return unless generation

    edited = flashcards.count { |f| f.source_ai_edited? }
    unedited = flashcards.count { |f| f.source_ai_generated? }

    generation.update!(
      accepted_edited_count: generation.accepted_edited_count + edited,
      accepted_unedited_count: generation.accepted_unedited_count + unedited
    )
  end
end
