import { Controller } from "@hotwired/stimulus";
import {
  validateProposal,
  resolveSource,
} from "../helpers/generations_helpers";

/**
 * Controls a single proposal card: selection toggle, inline edit, reject.
 * Exposes isSelected and toPayload() for the parent proposals-list controller.
 */
export default class extends Controller {
  static targets = [
    "checkbox",
    "display",
    "editForm",
    "frontDisplay",
    "backDisplay",
    "editedBadge",
    "frontInput",
    "backInput",
    "frontError",
    "backError",
  ];

  static values = {
    front: String,
    back: String,
    originalFront: String,
    originalBack: String,
    selected: { type: Boolean, default: true },
  };

  // ── Public API (called via outlet) ──

  get isSelected() {
    return this.selectedValue;
  }

  toPayload() {
    return {
      front: this.frontValue,
      back: this.backValue,
      source: resolveSource(
        this.originalFrontValue,
        this.originalBackValue,
        this.frontValue,
        this.backValue,
      ),
    };
  }

  select() {
    this.selectedValue = true;
    this._updateVisuals();
  }

  deselect() {
    this.selectedValue = false;
    this._updateVisuals();
  }

  // ── Actions ──

  toggle() {
    this.selectedValue = !this.selectedValue;
    this._updateVisuals();
    this.dispatch("changed");
  }

  startEdit() {
    this.frontInputTarget.value = this.frontValue;
    this.backInputTarget.value = this.backValue;
    this.displayTarget.classList.add("hidden");
    this.editFormTarget.classList.remove("hidden");
    this.frontInputTarget.focus();
  }

  cancelEdit() {
    this.editFormTarget.classList.add("hidden");
    this.displayTarget.classList.remove("hidden");
    this._clearErrors();
  }

  saveEdit() {
    const front = this.frontInputTarget.value.trim();
    const back = this.backInputTarget.value.trim();

    const errors = validateProposal(front, back);
    if (Object.keys(errors).length > 0) {
      this._showErrors(errors);
      return;
    }

    this.frontValue = front;
    this.backValue = back;
    this.frontDisplayTarget.textContent = front;
    this.backDisplayTarget.textContent = back;

    const isEdited =
      front !== this.originalFrontValue || back !== this.originalBackValue;
    this.editedBadgeTarget.classList.toggle("hidden", !isEdited);

    this.editFormTarget.classList.add("hidden");
    this.displayTarget.classList.remove("hidden");
    this._clearErrors();
    this.dispatch("changed");
  }

  reject() {
    this.dispatch("changed");
    this.element.remove();
  }

  // ── Lifecycle ──

  selectedValueChanged() {
    this._updateVisuals();
  }

  // ── Private ──

  _updateVisuals() {
    this.checkboxTarget.checked = this.selectedValue;

    const selectedClasses = [
      "border-blue-300",
      "dark:border-blue-600",
      "bg-blue-50/50",
      "dark:bg-blue-900/10",
    ];
    const deselectedClasses = [
      "border-gray-200",
      "dark:border-gray-700",
      "bg-white",
      "dark:bg-gray-800",
    ];

    if (this.selectedValue) {
      this.element.classList.add(...selectedClasses);
      this.element.classList.remove(...deselectedClasses);
    } else {
      this.element.classList.remove(...selectedClasses);
      this.element.classList.add(...deselectedClasses);
    }
  }

  _showErrors(errors) {
    if (errors.front) {
      this.frontErrorTarget.textContent = errors.front;
      this.frontErrorTarget.classList.remove("hidden");
    }
    if (errors.back) {
      this.backErrorTarget.textContent = errors.back;
      this.backErrorTarget.classList.remove("hidden");
    }
  }

  _clearErrors() {
    this.frontErrorTarget.textContent = "";
    this.frontErrorTarget.classList.add("hidden");
    this.backErrorTarget.textContent = "";
    this.backErrorTarget.classList.add("hidden");
  }
}
