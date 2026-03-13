# frozen_string_literal: true

module Ai
  # Klient OpenRouter do generowania fiszek z tekstu źródłowego.
  #
  # AKTUALNIE: Mock — zwraca sztywne propozycje bez wywołania API.
  # TODO: Zaimplementować prawdziwe wywołanie HTTP do OpenRouter.ai
  #       z timeoutami, retry i walidacją struktury odpowiedzi.
  class OpenrouterClient
    MOCK_MODEL = 'mock/gpt-4o-mini'

    # @param source_text [String] tekst źródłowy do analizy
    # @return [Hash] { success: Boolean, proposals: Array<Hash>, model: String }
    #   lub { success: false, error_code: String, error_message: String }
    def self.generate_flashcards(source_text)
      # TODO: Zastąp prawdziwym wywołaniem OpenRouter API
      proposals = build_mock_proposals(source_text)

      {
        success: true,
        proposals:,
        model: MOCK_MODEL
      }
    rescue StandardError => e
      {
        success: false,
        error_code: 'ai_error',
        error_message: "AI service error: #{e.message}"
      }
    end

    # ── Private ──────────────────────────────────────────────

    def self.build_mock_proposals(source_text)
      # Generuje 3 mockowe propozycje fiszek na podstawie fragmentów tekstu
      sentences = source_text.split(/[.!?]+/).map(&:strip).reject(&:blank?)
      proposals_count = [ sentences.size, 3 ].min

      proposals_count.times.map do |i|
        {
          id: (i + 1).to_s,
          front: "Question #{i + 1}: What does this mean?",
          back: sentences[i].to_s.truncate(500),
          source: 'ai-full'
        }
      end
    end

    private_class_method :build_mock_proposals
  end
end
