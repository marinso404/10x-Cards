import { Controller } from "@hotwired/stimulus";

/**
 * Reusable character counter for textareas.
 * Uses a template string with {count} and {max} placeholders.
 */
export default class extends Controller {
  static targets = ["input", "display"];
  static values = { max: Number, template: String };

  connect() {
    this.update();
  }

  update() {
    const count = this.inputTarget.value.length;
    this.displayTarget.textContent = this.templateValue
      .replace("{count}", count.toLocaleString())
      .replace("{max}", this.maxValue.toLocaleString());
  }
}
