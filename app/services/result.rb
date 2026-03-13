# frozen_string_literal: true

# Generyczny obiekt wyniku dla Service Objects.
# Zapewnia spójny interfejs: success?, data, errors, error_code.
#
# Użycie:
#   Result.success(data: { id: 1 })
#   Result.failure(errors: ["not found"], error_code: :not_found)
class Result
  attr_reader :data, :errors, :error_code

  def initialize(success:, data: {}, errors: [], error_code: nil)
    @success = success
    @data = data
    @errors = Array(errors)
    @error_code = error_code
  end

  def success? = @success
  def failure? = !@success

  def self.success(data: {})
    new(success: true, data:)
  end

  def self.failure(errors:, error_code: :unknown)
    new(success: false, errors: Array(errors), error_code:)
  end
end
