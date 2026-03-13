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
      return render_generation_error(
        message: I18n.t('api.generations.errors.source_text_missing'),
        json_status: :bad_request
      )
    end

    unless source_text.length.in?(1000..10_000)
      return render_generation_error(
        message: I18n.t('api.generations.errors.source_text_length'),
        json_status: :bad_request
      )
    end

    result = Generations::CreateFromSourceText.call(
      user: current_user,
      source_text:
    )

    if result.success?
      @generation_id = result.data[:generation_id]
      @proposals = result.data[:flashcards_proposals]
      @generated_count = result.data[:generated_count]

      respond_to do |format|
        format.turbo_stream
        format.json do
          render json: {
            generation_id: @generation_id,
            flashcards_proposals: @proposals,
            generated_count: @generated_count
          }, status: :created
        end
      end
    else
      handle_service_error(result)
    end
  end

  private

  def generation_params
    params.permit(:source_text)
  end

  def render_generation_error(message:, json_status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          'status-banner',
          partial: 'generations/status_banner',
          locals: { kind: 'error', title: I18n.t('generations.new.status.error_title'), body: message }
        ), status: :unprocessable_entity
      end
      format.json { render_error(code: 'invalid_request', message:, status: json_status) }
    end
  end

  def handle_service_error(result)
    respond_to do |format|
      format.turbo_stream do
        message = result.error_code == :duplicate ? result.errors.join(', ') : I18n.t('api.generations.errors.generation_failed')
        render turbo_stream: turbo_stream.replace(
          'status-banner',
          partial: 'generations/status_banner',
          locals: { kind: 'error', title: I18n.t('generations.new.status.error_title'), body: message }
        ), status: :unprocessable_entity
      end
      format.json do
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
  end
end
