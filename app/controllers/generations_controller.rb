# frozen_string_literal: true

class GenerationsController < ApplicationController
  before_action :authenticate_user!, only: [ :create ]

  # GET /generations/new
  def new
  end

  # POST /generations
  def create
    source_text = generation_params[:source_text].to_s

    if source_text.blank?
      return render_error(
        code: 'invalid_request',
        message: I18n.t('api.generations.errors.source_text_missing'),
        status: :bad_request
      )
    end

    unless source_text.length.in?(1000..10_000)
      return render_error(
        code: 'invalid_request',
        message: I18n.t('api.generations.errors.source_text_length'),
        status: :bad_request
      )
    end

    result = Generations::CreateFromSourceText.call(
      user: current_user,
      source_text:
    )

    if result.success?
      render json: {
        generation_id: result.data[:generation_id],
        flashcards_proposals: result.data[:flashcards_proposals],
        generated_count: result.data[:generated_count]
      }, status: :created
    else
      handle_service_error(result)
    end
  end

  private

  def generation_params
    params.permit(:source_text)
  end

  def handle_service_error(result)
    case result.error_code
    when :invalid_request
      render_error(code: 'invalid_request', message: result.errors.join(', '), status: :bad_request)
    when :duplicate
      render_error(code: 'invalid_request', message: result.errors.join(', '), status: :unprocessable_entity)
    else
      render_error(
        code: 'generation_failed',
        message: I18n.t('api.generations.errors.generation_failed'),
        status: :internal_server_error
      )
    end
  end
end
