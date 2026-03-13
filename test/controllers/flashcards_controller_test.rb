# frozen_string_literal: true

require 'test_helper'

class FlashcardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    login_as(@user)
    # Create a generation for linking flashcards
    @generation = Generation.create!(
      user: @user,
      source_text: 'a' * 1500,
      model: 'mock/gpt-4o-mini',
      generation_duration: 100,
      generated_count: 2
    )
  end

  def post_flashcards(payload)
    post flashcards_url,
         params: payload.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  end

  # ── Validation ─────────────────────────────────────────

  test 'returns 400 when flashcards array is empty' do
    post_flashcards(flashcards: [])
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal 'invalid_request', json.dig('error', 'code')
  end

  test 'returns 400 when flashcards key is missing' do
    post_flashcards({})
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal 'invalid_request', json.dig('error', 'code')
  end

  test 'returns 422 when flashcard front is blank' do
    post_flashcards(flashcards: [
      { front: '', back: 'Valid back', source: 'ai_generated', generation_id: @generation.id }
    ])
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal 'invalid_request', json.dig('error', 'code')
  end

  test 'returns 422 when flashcard front exceeds 200 chars' do
    post_flashcards(flashcards: [
      { front: 'a' * 201, back: 'Valid back', source: 'ai_generated', generation_id: @generation.id }
    ])
    assert_response :unprocessable_entity
  end

  test 'returns 422 when flashcard back exceeds 500 chars' do
    post_flashcards(flashcards: [
      { front: 'Valid front', back: 'a' * 501, source: 'ai_generated', generation_id: @generation.id }
    ])
    assert_response :unprocessable_entity
  end

  test 'returns 422 when source is invalid' do
    post_flashcards(flashcards: [
      { front: 'Valid front', back: 'Valid back', source: 'invalid_source', generation_id: @generation.id }
    ])
    assert_response :unprocessable_entity
  end

  # ── Success ────────────────────────────────────────────

  test 'creates flashcards and returns 201 with data' do
    assert_difference 'Flashcard.count', 2 do
      post_flashcards(flashcards: [
        { front: 'Q1', back: 'A1', source: 'ai_generated', generation_id: @generation.id },
        { front: 'Q2', back: 'A2', source: 'ai_edited', generation_id: @generation.id }
      ])
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json.dig('data', 'count')
    assert_equal 2, json.dig('data', 'created_flashcards').size

    created = json.dig('data', 'created_flashcards')
    assert created.all? { |f| f['id'].present? }
    assert created.any? { |f| f['source'] == 'ai_generated' }
    assert created.any? { |f| f['source'] == 'ai_edited' }
  end

  test 'assigns flashcards to current user' do
    post_flashcards(flashcards: [
      { front: 'Q1', back: 'A1', source: 'ai_generated', generation_id: @generation.id }
    ])
    assert_response :created
    assert_equal @user.id, Flashcard.last.user_id
  end

  test 'updates generation accepted counts' do
    post_flashcards(flashcards: [
      { front: 'Q1', back: 'A1', source: 'ai_generated', generation_id: @generation.id },
      { front: 'Q2', back: 'A2', source: 'ai_edited', generation_id: @generation.id },
      { front: 'Q3', back: 'A3', source: 'ai_generated', generation_id: @generation.id }
    ])
    assert_response :created

    @generation.reload
    assert_equal 2, @generation.accepted_unedited_count
    assert_equal 1, @generation.accepted_edited_count
  end

  test 'creates flashcards without generation_id (manual)' do
    assert_difference 'Flashcard.count', 1 do
      post_flashcards(flashcards: [
        { front: 'Manual Q', back: 'Manual A', source: 'manual' }
      ])
    end
    assert_response :created
    assert_nil Flashcard.last.generation_id
  end

  # ── Atomicity ──────────────────────────────────────────

  test 'rolls back all flashcards if one is invalid' do
    assert_no_difference 'Flashcard.count' do
      post_flashcards(flashcards: [
        { front: 'Valid Q', back: 'Valid A', source: 'ai_generated', generation_id: @generation.id },
        { front: '', back: 'A2', source: 'ai_generated', generation_id: @generation.id }
      ])
    end
    assert_response :unprocessable_entity
  end

  private

  def login_as(user)
    ApplicationController.define_method(:current_user) { user }
  end
end
