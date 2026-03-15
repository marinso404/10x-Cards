# frozen_string_literal: true

module Generations
  # Orchestracja tworzenia generacji fiszek z tekstu źródłowego.
  #
  # Przepływ:
  #   1. Normalizacja source_text (strip)
  #   2. Wyliczenie source_text_hash (SHA256)
  #   3. Utworzenie rekordu Generation
  #   4. Wywołanie AI (aktualnie mock) → propozycje fiszek
  #   5. Aktualizacja metadanych generacji (generated_count, duration, model)
  #   6. Zwrócenie Result z danymi
  #
  # W przypadku błędu AI/DB: zapis do generation_error_logs, zwrot Result.failure.
  class CreateFromSourceText
    def self.call(user:, source_text:)
      new(user:, source_text:).call
    end

    def initialize(user:, source_text:)
      @user = user
      @source_text = source_text.strip
    end

    def call
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # Najpierw wywołanie AI — nie tworzymy rekordu Generation z fałszywymi danymi
      ai_result = fetch_ai_proposals

      unless ai_result[:success]
        return Result.failure(errors: [ ai_result[:error_message] ], error_code: :ai_error)
      end

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i
      proposals = ai_result[:proposals]

      # Tworzenie rekordu Generation z pełnymi, prawdziwymi danymi
      generation = build_generation(
        model: ai_result[:model],
        generation_duration: duration_ms,
        generated_count: proposals.size
      )

      unless generation.save
        return Result.failure(
          errors: generation.errors.full_messages,
          error_code: generation.errors[:source_text_hash].any? ? :duplicate : :invalid_request
        )
      end

      log_success(generation, duration_ms)

      Result.success(data: {
        generation_id: generation.id,
        flashcards_proposals: proposals,
        generated_count: proposals.size
      })
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.warn("[Generations] Duplicate source_text_hash for user_id=#{user.id}")
      Result.failure(errors: [ 'Duplicate source text for this user' ], error_code: :duplicate)
    rescue StandardError => e
      Rails.logger.error("[Generations] Unexpected error for user_id=#{user.id}: #{e.class} — #{e.message}")
      log_error_safe(generation, e)
      Result.failure(errors: [ 'Generation failed' ], error_code: :generation_failed)
    end

    private

    attr_reader :user, :source_text

    def build_generation(model:, generation_duration:, generated_count:)
      user.generations.build(
        source_text:,
        model:,
        generation_duration:,
        generated_count:
      )
    end

    # ── AI Client ───────────────────────────────────────────
    def fetch_ai_proposals
      client = Ai::OpenrouterClient.new
      result = client.generate_flashcards(source_text:)

      if result.success?
        { success: true, proposals: result.data[:proposals], model: result.data[:model] }
      else
        { success: false, error_code: result.error_code.to_s, error_message: result.errors.join(', ') }
      end
    end

    # ── Error logging ────────────────────────────────────────

    def log_error(generation, code, message)
      return unless generation&.persisted?

      generation.generation_error_logs.create!(
        error_code: code.to_s,
        error_message: message.to_s.truncate(1000),
        occurred_at: Time.current
      )
    end

    def log_success(generation, duration_ms)
      Rails.logger.info(
        "[Generations] Created generation_id=#{generation.id} " \
        "model=#{generation.model} duration=#{duration_ms}ms " \
        "generated_count=#{generation.generated_count} user_id=#{user.id}"
      )
    end

    def log_error_safe(generation, exception)
      log_error(generation, exception.class.name, exception.message)
    rescue StandardError => log_err
      Rails.logger.error("[Generations::CreateFromSourceText] Failed to log error: #{log_err.message}")
    end
  end
end
