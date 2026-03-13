# frozen_string_literal: true

require 'test_helper'

class GenerationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @valid_source_text = 'a' * 1500
  end

  # ── GET /generations/new ───────────────────────────────

  test 'renders the new generation page' do
    get new_generation_url
    assert_response :success
    assert_select 'h1', I18n.t('generations.new.title')
    assert_select 'textarea#source_text'
    assert_select '[data-controller="generations-new"]'
  end

  # ── POST /generations ──────────────────────────────────

  def post_generation(source_text: @valid_source_text, headers: {})
    post generations_url,
         params: { source_text: }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }.merge(headers)
  end

  test 'returns 400 when source_text is blank' do
    login_as(@user)
    post generations_url,
         params: { source_text: '' }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal 'invalid_request', json.dig('error', 'code')
  end

  test 'returns 400 when source_text is too short' do
    login_as(@user)
    post generations_url,
         params: { source_text: 'short' }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal 'invalid_request', json.dig('error', 'code')
    assert_match(/1000.*10000/, json.dig('error', 'message'))
  end

  test 'returns 400 when source_text is too long' do
    login_as(@user)
    post generations_url,
         params: { source_text: 'a' * 10_001 }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal 'invalid_request', json.dig('error', 'code')
  end

  test 'returns 201 with flashcard proposals on success' do
    login_as(@user)
    post generations_url,
         params: { source_text: @valid_source_text }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    assert_response :created
    json = JSON.parse(response.body)
    assert json['generation_id'].present?
    assert json['flashcards_proposals'].is_a?(Array)
    assert json['generated_count'].is_a?(Integer)
    assert json['generated_count'] > 0
    proposal = json['flashcards_proposals'].first
    assert proposal['id'].present?
    assert proposal['front'].present?
    assert proposal['back'].present?
    assert_equal 'ai-full', proposal['source']
  end

  test 'creates a Generation record in the database' do
    login_as(@user)
    assert_difference 'Generation.count', 1 do
      post generations_url,
           params: { source_text: @valid_source_text }.to_json,
           headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    end
    generation = Generation.last
    assert_equal @user.id, generation.user_id
    assert_equal @valid_source_text, generation.source_text
    assert generation.generation_duration >= 0
    assert generation.model.present?
  end

  test 'returns 500 when AI service fails' do
    login_as(@user)
    original = Ai::OpenrouterClient.method(:generate_flashcards)
    Ai::OpenrouterClient.define_singleton_method(:generate_flashcards) do |_|
      { success: false, error_code: 'ai_error', error_message: 'Service unavailable' }
    end
    post generations_url,
         params: { source_text: @valid_source_text }.to_json,
         headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
  ensure
    Ai::OpenrouterClient.define_singleton_method(:generate_flashcards, original)
    assert_response :internal_server_error
    json = JSON.parse(response.body)
    assert_equal 'generation_failed', json.dig('error', 'code')
  end

  private

  def login_as(user)
    ApplicationController.define_method(:current_user) { user }
  end

  teardown do
    ApplicationController.define_method(:current_user) do
      return @current_user if defined?(@current_user)

      @current_user = User.first
    end
  end
end
