class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from ActionController::ParameterMissing, with: :handle_bad_request

  private

  # ── Autentykacja ──────────────────────────────────────────

  def current_user
    return @current_user if defined?(@current_user)

    # TODO — tymczasowo zwracamy pierwszego usera, docelowo będzie to opierać się na sesji lub tokenie
    @current_user = User.first
  end

  def authenticate_user!
    return if current_user

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          'status-banner',
          partial: 'generations/status_banner',
          locals: { kind: 'error', title: I18n.t('api.errors.unauthorized'), body: I18n.t('api.errors.unauthorized') }
        ), status: :unprocessable_entity
      end
      format.json do
        render json: {
          error: { code: 'unauthorized', message: I18n.t('api.errors.unauthorized') }
        }, status: :unauthorized
      end
      format.html { redirect_to root_path }
    end
  end

  # ── Wspólne helpery odpowiedzi ───────────────────────────

  def render_error(code:, message:, status:)
    render json: { error: { code:, message: } }, status:
  end

  def handle_bad_request(exception)
    render_error(
      code: 'invalid_request',
      message: exception.message,
      status: :bad_request
    )
  end

  helper_method :current_user
end
