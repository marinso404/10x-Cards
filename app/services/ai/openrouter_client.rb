# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Ai
  # Klient HTTP do komunikacji z OpenRouter API (chat/completions).
  #
  # Obsługuje:
  #   - budowanie payloadu (messages, response_format, model_params)
  #   - timeouty, retry z backoff dla błędów przejściowych
  #   - parsowanie i walidację strukturalnej odpowiedzi JSON
  #   - mapowanie błędów HTTP/sieciowych na domenowe error_code
  #
  # Zależności wstrzykiwane przez konstruktor (DI) dla testowalności:
  #   http_client, logger, api_key.
  class OpenrouterClient
    # ── Stałe ──────────────────────────────────────────────

    DEFAULT_MODEL = 'openai/gpt-4.1-mini'
    BASE_URL = 'https://openrouter.ai/api/v1'

    DEFAULT_TIMEOUTS = { connect: 10, read: 60, write: 30 }.freeze

    ALLOWED_MODELS = %w[
      openai/gpt-4.1-mini
      openai/gpt-4.1-nano
      openai/gpt-4o-mini
    ].freeze

    DEFAULT_MODEL_PARAMS = { temperature: 0.2, max_tokens: 1200, top_p: 0.9 }.freeze

    ERROR_CODES = {
      configuration_error: 'configuration_error',
      network_error: 'network_error',
      provider_error: 'provider_error',
      rate_limited: 'rate_limited',
      invalid_request: 'invalid_request',
      invalid_response_format: 'invalid_response_format',
      validation_error: 'validation_error',
      ai_error: 'ai_error'
    }.freeze

    MAX_SOURCE_TEXT_LENGTH = 10_000
    MAX_RETRIES = 2

    # ── Błędy domenowe ───────────────────────────────────

    class ConfigurationError < StandardError; end
    class NetworkError < StandardError; end
    class InvalidResponseError < StandardError; end
    class InvalidResponseFormatError < StandardError; end
    class ValidationError < StandardError; end

    class ProviderError < StandardError
      attr_reader :error_code

      def initialize(message, error_code = :provider_error)
        @error_code = error_code
        super(message)
      end
    end

    # ── Konstruktor ──────────────────────────────────────

    def initialize(
      api_key: default_api_key,
      http_client: nil,
      base_url: BASE_URL,
      timeout_config: DEFAULT_TIMEOUTS,
      default_model: DEFAULT_MODEL,
      default_params: DEFAULT_MODEL_PARAMS,
      logger: Rails.logger
    )
      @api_key = api_key
      @http_client = http_client
      @base_url = base_url
      @timeouts = timeout_config
      @default_model = default_model
      @default_params = default_params
      @logger = logger

      validate_configuration!
    end

    # ── Metody publiczne ─────────────────────────────────

    # Główna metoda do wywołania OpenRouter chat/completions.
    #
    # @param system_message [String]
    # @param user_message [String]
    # @param response_schema [Hash] { name: String, schema: Hash }
    # @param model [String, nil] nadpisanie modelu domyślnego
    # @param model_params [Hash] nadpisanie parametrów modelu
    # @return [Result] success(data: { content:, parsed:, model:, usage: }) | failure
    def generate_chat(system_message:, user_message:, response_schema:, model: nil, model_params: {})
      resolved_model = resolve_model(model)
      messages = build_messages(system_message:, user_message:)
      response_format = build_response_format(schema_name: response_schema[:name], schema_obj: response_schema[:schema])
      merged_params = default_params.merge(model_params)

      payload = build_payload(model: resolved_model, messages:, response_format:, model_params: merged_params)

      result = with_retry_for_transient_errors do
        raw_response = perform_request(payload)
        parsed = parse_provider_response(raw_response)
        validate_structured_output!(parsed[:content_parsed], response_schema[:schema])
        parsed
      end

      Result.success(data: {
        content: result[:content_raw],
        parsed: result[:content_parsed],
        model: result[:model],
        usage: result[:usage]
      })
    rescue ConfigurationError, NetworkError, ProviderError,
           InvalidResponseError, InvalidResponseFormatError, ValidationError => e
      handle_error(e)
    rescue StandardError => e
      handle_error(e)
    end

    # Metoda wyspecjalizowana dla domeny fiszek.
    #
    # @param source_text [String]
    # @param count [Integer] liczba fiszek do wygenerowania (1..20)
    # @param locale [String] język fiszek
    # @return [Result] success(data: { proposals:, model:, usage: }) | failure
    def generate_flashcards(source_text:, count: 5, locale: 'pl')
      sanitized_text = sanitize_source_text(source_text)
      clamped_count = count.clamp(1, 20)

      result = generate_chat(
        system_message: build_flashcards_system_prompt(locale:),
        user_message: build_flashcards_user_prompt(source_text: sanitized_text, count: clamped_count),
        response_schema: flashcards_response_schema,
        model_params: { temperature: 0.2, max_tokens: 1200 }
      )

      return result unless result.success?

      proposals = result.data[:parsed]['flashcards'].map(&:symbolize_keys)

      Result.success(data: {
        proposals:,
        model: result.data[:model],
        usage: result.data[:usage]
      })
    end

    # Walidacja konfiguracji i dostępności upstreamu (bez kosztownych requestów).
    #
    # @return [Result]
    def healthcheck
      validate_configuration!
      Result.success(data: { status: 'ok', model: default_model, base_url: })
    rescue ConfigurationError => e
      Result.failure(errors: [ e.message ], error_code: :configuration_error)
    end

    private

    attr_reader :api_key, :http_client, :base_url, :timeouts, :logger, :default_model, :default_params

    # ── Konfiguracja ─────────────────────────────────────

    def default_api_key
      Rails.application.credentials.dig(:openrouter, :api_key) || ENV['OPENROUTER_API_KEY']
    end

    def validate_configuration!
      raise ConfigurationError, 'OPENROUTER_API_KEY is not set' if api_key.blank?
      raise ConfigurationError, "Model not allowed: #{default_model}" unless ALLOWED_MODELS.include?(default_model)
    end

    def resolve_model(model)
      return default_model if model.nil?

      raise ConfigurationError, "Model not allowed: #{model}" unless ALLOWED_MODELS.include?(model)

      model
    end

    # ── Budowanie wiadomości (Prompt Builder) ────────────

    def build_messages(system_message:, user_message:)
      [
        { role: 'system', content: system_message },
        { role: 'user', content: user_message }
      ]
    end

    def build_flashcards_system_prompt(locale:)
      <<~PROMPT.strip
        You are an educational assistant specializing in creating high-quality flashcards.
        Generate flashcards that are concise, accurate, and based solely on the provided source text.
        Do not include information from outside the source text.
        Return only valid JSON conforming to the provided schema.
        Language for flashcards: #{locale}.
      PROMPT
    end

    def build_flashcards_user_prompt(source_text:, count:)
      <<~PROMPT.strip
        Create #{count} flashcards based on the following text.
        Each flashcard should have a clear question on the front and a concise answer on the back.

        ---
        <source_text>#{source_text}</source_text>
        ---
      PROMPT
    end

    # ── Response Format (JSON Schema) ────────────────────

    def build_response_format(schema_name:, schema_obj:)
      {
        type: 'json_schema',
        json_schema: {
          name: schema_name,
          strict: true,
          schema: schema_obj
        }
      }
    end

    def flashcards_response_schema
      {
        name: 'flashcards_response',
        schema: {
          type: 'object',
          additionalProperties: false,
          required: [ 'flashcards' ],
          properties: {
            flashcards: {
              type: 'array',
              items: {
                type: 'object',
                additionalProperties: false,
                required: %w[front back source],
                properties: {
                  front: { type: 'string' },
                  back: { type: 'string' },
                  source: { type: 'string', enum: [ 'ai-full' ] }
                }
              }
            }
          }
        }
      }
    end

    # ── Budowanie payloadu ───────────────────────────────

    def build_payload(model:, messages:, response_format:, model_params:)
      { model:, messages:, response_format:, **model_params }
    end

    # ── HTTP ─────────────────────────────────────────────

    def perform_request(payload)
      uri = URI("#{base_url}/chat/completions")

      return http_client.post(uri, payload, request_headers) if http_client

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = timeouts[:connect]
      http.read_timeout = timeouts[:read]
      http.write_timeout = timeouts[:write]

      request = Net::HTTP::Post.new(uri.path)
      request_headers.each { |k, v| request[k] = v }
      request.body = JSON.generate(payload)

      log_request(payload)

      response = http.request(request)
      handle_http_status!(response)

      JSON.parse(response.body)
    end

    def request_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}",
        'HTTP-Referer' => 'https://ten-x-cards.app',
        'X-Title' => '10x Cards'
      }
    end

    # ── Parsowanie odpowiedzi dostawcy ───────────────────

    def parse_provider_response(raw_response)
      choices = raw_response['choices']
      raise InvalidResponseError, 'No choices in API response' if choices.nil? || choices.empty?

      message = choices.dig(0, 'message')
      raise InvalidResponseError, 'No message in response choice' if message.nil?

      content_raw = message['content']
      raise InvalidResponseError, 'Empty content in response' if content_raw.blank?

      content_parsed = parse_json_content(content_raw)

      { content_raw:, content_parsed:, model: raw_response['model'], usage: raw_response['usage'] }
    end

    def parse_json_content(content_raw)
      JSON.parse(content_raw)
    rescue JSON::ParserError => e
      raise InvalidResponseFormatError, "Model returned invalid JSON: #{e.message}"
    end

    # ── Walidacja struktury odpowiedzi ───────────────────

    def validate_structured_output!(parsed_json, schema_obj)
      required_keys = schema_obj[:required] || schema_obj['required'] || []
      required_keys.each do |key|
        raise ValidationError, "Missing required key: #{key}" unless parsed_json.key?(key)
      end

      validate_flashcards_array!(parsed_json['flashcards']) if parsed_json.key?('flashcards')
    end

    def validate_flashcards_array!(flashcards)
      raise ValidationError, 'flashcards must be an array' unless flashcards.is_a?(Array)
      raise ValidationError, 'flashcards array is empty' if flashcards.empty?

      flashcards.each_with_index { |card, idx| validate_flashcard!(card, idx) }
    end

    def validate_flashcard!(card, index)
      %w[front back source].each do |field|
        raise ValidationError, "Flashcard ##{index}: missing '#{field}'" unless card.key?(field)
      end

      front_len = card['front'].to_s.length
      back_len = card['back'].to_s.length

      raise ValidationError, "Flashcard ##{index}: front too short (min 3)" if front_len < 3
      raise ValidationError, "Flashcard ##{index}: front too long (max 200)" if front_len > 200
      raise ValidationError, "Flashcard ##{index}: back too short (min 3)" if back_len < 3
      raise ValidationError, "Flashcard ##{index}: back too long (max 500)" if back_len > 500
      raise ValidationError, "Flashcard ##{index}: invalid source '#{card['source']}'" unless card['source'] == 'ai-full'
    end

    # ── Sanityzacja wejścia ──────────────────────────────

    def sanitize_source_text(text)
      sanitized = text.to_s.strip
      raise ValidationError, 'Source text is empty' if sanitized.blank?
      raise ValidationError, "Source text exceeds maximum length (#{MAX_SOURCE_TEXT_LENGTH})" if sanitized.length > MAX_SOURCE_TEXT_LENGTH

      sanitized
    end

    # ── Obsługa błędów HTTP ──────────────────────────────

    def handle_http_status!(response)
      code = response.code.to_i
      return if code.in?(200..299)

      body = safe_body(response)

      case code
      when 400      then raise ProviderError.new("Bad request: #{body}", :invalid_request)
      when 401, 403 then raise ProviderError.new('Authentication failed', :configuration_error)
      when 404, 422 then raise ProviderError.new("Invalid model or parameters: #{body}", :invalid_request)
      when 429      then raise ProviderError.new('Rate limited by provider', :rate_limited)
      when 500..599 then raise ProviderError.new("Provider unavailable (HTTP #{code})", :provider_error)
      else               raise ProviderError.new("Unexpected HTTP #{code}: #{body}", :provider_error)
      end
    end

    def handle_error(error)
      code = error_code_for(error)
      message = code == :ai_error ? 'AI service error' : error.message

      logger&.error("[Ai::OpenrouterClient] #{error.class}: #{error.message}") unless code == :ai_error
      logger&.error("[Ai::OpenrouterClient] Unexpected: #{error.class} — #{error.message}") if code == :ai_error

      Result.failure(errors: [ message ], error_code: code)
    end

    def error_code_for(error)
      case error
      when ConfigurationError        then :configuration_error
      when NetworkError               then :network_error
      when ProviderError              then error.error_code
      when InvalidResponseFormatError then :invalid_response_format
      when InvalidResponseError       then :invalid_response_format
      when ValidationError            then :validation_error
      else                                 :ai_error
      end
    end

    # ── Retry z backoff ──────────────────────────────────

    def with_retry_for_transient_errors
      attempts = 0

      begin
        attempts += 1
        yield
      rescue ProviderError => e
        raise unless retriable_provider?(e) && attempts <= MAX_RETRIES

        wait_and_log(attempts, e)
        retry
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED, SocketError => e
        raise NetworkError, "Network error: #{e.message}" if attempts > MAX_RETRIES

        wait_and_log(attempts, e)
        retry
      end
    end

    def retriable_provider?(error)
      %i[provider_error rate_limited].include?(error.error_code)
    end

    def wait_and_log(attempt, error)
      delay = (2**attempt) + rand(0.0..0.5)
      logger&.warn(
        "[Ai::OpenrouterClient] Transient error (attempt #{attempt}/#{MAX_RETRIES + 1}): " \
        "#{error.message}. Retrying in #{delay.round(1)}s"
      )
      sleep(delay)
    end

    # ── Logowanie (bezpieczne) ───────────────────────────

    def log_request(payload)
      logger&.info("[Ai::OpenrouterClient] Request: model=#{payload[:model]}")
      logger&.debug { "[Ai::OpenrouterClient] Payload: #{sanitize_for_logs(payload)}" }
    end

    def sanitize_for_logs(payload)
      data = payload.deep_dup
      if data[:messages].is_a?(Array)
        data[:messages] = data[:messages].map { |msg| msg.merge(content: msg[:content].to_s.truncate(200)) }
      end
      data.except(:response_format)
    end

    def safe_body(response)
      response.body.to_s.truncate(500)
    end
  end
end
