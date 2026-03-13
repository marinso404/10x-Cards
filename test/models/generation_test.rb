# frozen_string_literal: true

require 'test_helper'

class GenerationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @valid_attrs = {
      user: @user,
      source_text: 'a' * 1500,
      model: 'test-model',
      generation_duration: 100,
      generated_count: 3
    }
  end

  test 'valid generation' do
    generation = Generation.new(@valid_attrs)
    assert generation.valid?
  end

  test 'requires user' do
    generation = Generation.new(@valid_attrs.except(:user))
    assert_not generation.valid?
  end

  test 'requires source_text' do
    generation = Generation.new(@valid_attrs.merge(source_text: nil))
    assert_not generation.valid?
  end

  test 'requires source_text minimum 1000 chars' do
    generation = Generation.new(@valid_attrs.merge(source_text: 'a' * 999))
    assert_not generation.valid?
    assert generation.errors[:source_text].any?
  end

  test 'requires source_text maximum 10000 chars' do
    generation = Generation.new(@valid_attrs.merge(source_text: 'a' * 10_001))
    assert_not generation.valid?
    assert generation.errors[:source_text].any?
  end

  test 'requires model' do
    generation = Generation.new(@valid_attrs.merge(model: nil))
    assert_not generation.valid?
  end

  test 'requires generation_duration' do
    generation = Generation.new(@valid_attrs.merge(generation_duration: nil))
    assert_not generation.valid?
  end

  test 'auto-generates source_text_hash' do
    generation = Generation.new(@valid_attrs)
    generation.valid?
    assert_equal Digest::SHA256.hexdigest('a' * 1500), generation.source_text_hash
  end

  test 'auto-generates source_text_length' do
    generation = Generation.new(@valid_attrs)
    generation.valid?
    assert_equal 1500, generation.source_text_length
  end

  test 'enforces uniqueness of source_text_hash per user' do
    Generation.create!(@valid_attrs)

    duplicate = Generation.new(@valid_attrs)
    assert_not duplicate.valid?
    assert duplicate.errors[:source_text_hash].any?
  end

  test 'allows same source_text for different users' do
    Generation.create!(@valid_attrs)

    other_user = users(:two)
    generation = Generation.new(@valid_attrs.merge(user: other_user))
    assert generation.valid?
  end
end
