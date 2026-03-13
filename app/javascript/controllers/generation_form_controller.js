import { Controller } from "@hotwired/stimulus";
import { validateSourceText } from "../helpers/generations_helpers";

/**
 * Handles source text form submission via Turbo.
 * Validates client-side before Turbo intercepts, shows/hides loader.
 */
export default class extends Controller {
  static targets = [
    "sourceText",
    "fieldError",
    "submitBtn",
    "submitSpinner",
    "loader",
  ];

  static values = {
    minLength: { type: Number, default: 1000 },
    maxLength: { type: Number, default: 10000 },
  };

  validate(event) {
    this._clearFieldError();
    const error = validateSourceText(this.sourceTextTarget.value);
    if (error) {
      event.preventDefault();
      this._showFieldError(error);
    }
  }

  showLoader() {
    this.submitBtnTarget.disabled = true;
    this.submitSpinnerTarget.classList.remove("hidden");
    this.loaderTarget.classList.remove("hidden");
    this.sourceTextTarget.disabled = true;
  }

  hideLoader() {
    this.submitBtnTarget.disabled = false;
    this.submitSpinnerTarget.classList.add("hidden");
    this.loaderTarget.classList.add("hidden");
    this.sourceTextTarget.disabled = false;
  }

  // ── Private ──

  _showFieldError(msg) {
    this.fieldErrorTarget.textContent = msg;
    this.fieldErrorTarget.classList.remove("hidden");
  }

  _clearFieldError() {
    this.fieldErrorTarget.textContent = "";
    this.fieldErrorTarget.classList.add("hidden");
  }
}
