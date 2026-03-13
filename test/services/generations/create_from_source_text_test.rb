# frozen_string_literal: true

require 'test_helper'

class Generations::CreateFromSourceTextTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @valid_source_text = 'a' * 1500
  end

  # ── Sukces ─────────────────────────────────────────────────

  test 'returns success with generation data' do
    result = Generations::CreateFromSourceText.call(
      user: @user,
      source_text: @valid_source_text
    )

    assert result.success?
    assert result.data[:generation_id].present?
    assert result.data[:flashcards_proposals].is_a?(Array)
    assert result.data[:generated_count] > 0
  end

  test 'creates a Generation record' do
    assert_difference 'Generation.count', 1 do
      Generations::CreateFromSourceText.call(
        user: @user,
        source_text: @valid_source_text
      )
    end
  end

  test 'sets correct generation attributes' do
    result = Generations::CreateFromSourceText.call(
      user: @user,
      source_text: @valid_source_text
    )

    generation = Generation.find(result.data[:generation_id])
    assert_equal @user.id, generation.user_id
    assert_equal @valid_source_text, generation.source_text
    assert_equal Digest::SHA256.hexdigest(@valid_source_text), generation.source_text_hash
    assert_equal @valid_source_text.length, generation.source_text_length
    assert generation.generation_duration >= 0
    assert_equal 'mock/gpt-4o-mini', generation.model
  end

  # ── Strip normalization ────────────────────────────────────

  test 'strips whitespace from source_text' do
    padded_text = "  #{@valid_source_text}  "

    result = Generations::CreateFromSourceText.call(
      user: @user,
      source_text: padded_text
    )

    assert result.success?
    generation = Generation.find(result.data[:generation_id])
    assert_equal @valid_source_text, generation.source_text
  end

  # ── Duplikat hash ──────────────────────────────────────────

  test 'returns failure for duplicate source_text_hash' do
    Generations::CreateFromSourceText.call(user: @user, source_text: @valid_source_text)

    result = Generations::CreateFromSourceText.call(user: @user, source_text: @valid_source_text)

    assert result.failure?
    assert_equal :duplicate, result.error_code
  end

  # ── Błąd AI ────────────────────────────────────────────────

  test 'returns failure when AI service fails' do
    mock_ai_failure do
      result = Generations::CreateFromSourceText.call(
        user: @user,
        source_text: @valid_source_text
      )

      assert result.failure?
      assert_equal :ai_error, result.error_code
      assert_includes result.errors, 'Timeout'
    end
  end

  test 'does not create Generation record when AI fails' do
    mock_ai_failure do
      assert_no_difference 'Generation.count' do
        Generations::CreateFromSourceText.call(
          user: @user,
          source_text: @valid_source_text
        )
      end
    end
  end

  private

  def mock_ai_failure(&block)
    original = Ai::OpenrouterClient.method(:generate_flashcards)
    Ai::OpenrouterClient.define_singleton_method(:generate_flashcards) do |_|
      { success: false, error_code: 'ai_error', error_message: 'Timeout' }
    end
    block.call
  ensure
    Ai::OpenrouterClient.define_singleton_method(:generate_flashcards, original)
  end

  # ── Propozycje fiszek ──────────────────────────────────────

  test 'proposals have correct structure' do
    result = Generations::CreateFromSourceText.call(
      user: @user,
      source_text: @valid_source_text
    )

    proposal = result.data[:flashcards_proposals].first
    assert proposal[:id].present?
    assert proposal[:front].present?
    assert proposal[:back].present?
    assert_equal 'ai-full', proposal[:source]
  end
end
