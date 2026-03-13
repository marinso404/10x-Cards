import { Controller } from "@hotwired/stimulus";
import {
  validateSourceText,
  validateProposal,
  mapApiError,
  resolveSource,
} from "../helpers/generations_helpers";

/**
 * Stimulus controller for /generations/new view.
 * Manages state for: source text form, AI generation, proposals list,
 * inline editing, selection, bulk save and discard.
 */
export default class extends Controller {
  static targets = [
    "sourceText",
    "charCount",
    "fieldError",
    "submitBtn",
    "submitSpinner",
    "statusBanner",
    "statusIcon",
    "statusTitle",
    "statusBody",
    "statusAction",
    "loader",
    "loaderLabel",
    "proposalsSection",
    "proposalsList",
    "proposalCount",
    "bulkActions",
    "bulkCount",
    "saveBtn",
    "saveSpinner",
    "discardBtn",
  ];

  static values = {
    minLength: { type: Number, default: 1000 },
    maxLength: { type: Number, default: 10000 },
    generateUrl: String,
    flashcardsUrl: String,
  };

  // ── Lifecycle ───────────────────────────────────────────

  connect() {
    this.state = {
      generationId: null,
      proposals: [],
      isGenerating: false,
      isSaving: false,
      isDiscarding: false,
    };
  }

  // ── Source Text Form ────────────────────────────────────

  updateCharCount() {
    const len = this.sourceTextTarget.value.length;
    this.charCountTarget.textContent = `${len} / ${this.maxLengthValue} characters`;
    this._clearFieldError();
  }

  async generate(event) {
    event.preventDefault();

    const sourceText = this.sourceTextTarget.value.trim();

    // Local validation
    const validationError = validateSourceText(this.sourceTextTarget.value);
    if (validationError) {
      this._showFieldError(validationError);
      return;
    }

    this._setGenerating(true);
    this._hideStatus();
    this._clearProposals();

    try {
      const response = await fetch(this.generateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this._csrfToken(),
        },
        body: JSON.stringify({ source_text: sourceText }),
      });

      const data = await response.json();

      if (response.ok) {
        this.state.generationId = data.generation_id;
        this.state.proposals = data.flashcards_proposals.map((p, i) => ({
          localId: `proposal-${i}`,
          remoteId: p.id,
          front: p.front,
          back: p.back,
          originalFront: p.front,
          originalBack: p.back,
          sourceKind: "ai_generated",
          selected: true,
          editing: false,
          errors: {},
        }));
        this._renderProposals();
      } else {
        this._handleGenerateError(response.status, data);
      }
    } catch {
      this._showStatus(
        "error",
        "Error",
        "Network error. Please check your connection and try again.",
      );
    } finally {
      this._setGenerating(false);
    }
  }

  // ── Proposal Selection ──────────────────────────────────

  selectAll() {
    this.state.proposals.forEach((p) => (p.selected = true));
    this._renderProposals();
  }

  deselectAll() {
    this.state.proposals.forEach((p) => (p.selected = false));
    this._renderProposals();
  }

  toggleProposal(event) {
    const id = event.currentTarget.dataset.proposalId;
    const proposal = this.state.proposals.find((p) => p.localId === id);
    if (proposal) {
      proposal.selected = !proposal.selected;
      this._renderProposals();
    }
  }

  // ── Proposal Rejection ─────────────────────────────────

  rejectProposal(event) {
    const id = event.currentTarget.dataset.proposalId;
    this.state.proposals = this.state.proposals.filter((p) => p.localId !== id);
    this._renderProposals();

    if (this.state.proposals.length === 0) {
      this._clearProposals();
    }
  }

  // ── Inline Editing ──────────────────────────────────────

  startEdit(event) {
    const id = event.currentTarget.dataset.proposalId;
    const proposal = this.state.proposals.find((p) => p.localId === id);
    if (proposal) {
      proposal.editing = true;
      this._renderProposals();
    }
  }

  cancelEdit(event) {
    const id = event.currentTarget.dataset.proposalId;
    const proposal = this.state.proposals.find((p) => p.localId === id);
    if (proposal) {
      proposal.editing = false;
      proposal.errors = {};
      this._renderProposals();
    }
  }

  saveEdit(event) {
    const id = event.currentTarget.dataset.proposalId;
    const proposal = this.state.proposals.find((p) => p.localId === id);
    if (!proposal) return;

    const row = this.proposalsListTarget.querySelector(
      `[data-proposal-row="${id}"]`,
    );
    const frontInput = row.querySelector("[data-field='front']");
    const backInput = row.querySelector("[data-field='back']");
    const front = frontInput.value.trim();
    const back = backInput.value.trim();

    const errors = validateProposal(front, back);
    if (Object.keys(errors).length > 0) {
      proposal.errors = errors;
      this._renderProposals();
      return;
    }

    proposal.front = front;
    proposal.back = back;
    proposal.sourceKind = resolveSource(
      proposal.originalFront,
      proposal.originalBack,
      front,
      back,
    );
    proposal.editing = false;
    proposal.errors = {};
    this._renderProposals();
  }

  // ── Bulk Actions ────────────────────────────────────────

  async saveSelected() {
    const selected = this.state.proposals.filter((p) => p.selected);
    if (selected.length === 0) {
      this._showStatus(
        "warning",
        "No selection",
        "Select at least one proposal to save",
      );
      return;
    }

    // Validate all selected
    let hasErrors = false;
    for (const p of selected) {
      const errors = validateProposal(p.front, p.back);
      if (Object.keys(errors).length > 0) {
        p.errors = errors;
        hasErrors = true;
      }
    }
    if (hasErrors) {
      this._renderProposals();
      this._showStatus(
        "error",
        "Validation Error",
        "Some selected proposals have invalid content. Please fix them before saving.",
      );
      return;
    }

    this._setSaving(true);
    this._hideStatus();

    try {
      const payload = {
        flashcards: selected.map((p) => ({
          front: p.front,
          back: p.back,
          source: p.sourceKind,
          generation_id: this.state.generationId,
        })),
      };

      const response = await fetch(this.flashcardsUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this._csrfToken(),
        },
        body: JSON.stringify(payload),
      });

      if (response.ok) {
        const data = await response.json();
        const count = data.data?.count || selected.length;
        this._clearProposals();
        this._showStatus(
          "success",
          "Saved!",
          `Successfully saved ${count} flashcards!`,
        );
      } else {
        this._showStatus(
          "error",
          "Save Error",
          "Failed to save flashcards. Please try again.",
        );
      }
    } catch {
      this._showStatus(
        "error",
        "Error",
        "Network error. Please check your connection and try again.",
      );
    } finally {
      this._setSaving(false);
    }
  }

  discardAll() {
    this.state.proposals = [];
    this.state.generationId = null;
    this._clearProposals();
    this._showStatus("info", "Discarded", "All proposals have been discarded.");
  }

  // ── Status Banner ───────────────────────────────────────

  dismissStatus() {
    this._hideStatus();
  }

  // ── Private: State → DOM ────────────────────────────────

  _setGenerating(flag) {
    this.state.isGenerating = flag;
    this.sourceTextTarget.disabled = flag;
    this.submitBtnTarget.disabled = flag;
    this.submitSpinnerTarget.classList.toggle("hidden", !flag);
    this.loaderTarget.classList.toggle("hidden", !flag);
  }

  _setSaving(flag) {
    this.state.isSaving = flag;
    this.saveBtnTarget.disabled = flag;
    this.discardBtnTarget.disabled = flag;
    this.saveSpinnerTarget.classList.toggle("hidden", !flag);
  }

  _renderProposals() {
    const proposals = this.state.proposals;

    if (proposals.length === 0) {
      this.proposalsSectionTarget.classList.add("hidden");
      return;
    }

    this.proposalsSectionTarget.classList.remove("hidden");

    const selectedCount = proposals.filter((p) => p.selected).length;
    this.proposalCountTarget.textContent = `${selectedCount} of ${proposals.length} selected`;
    this.bulkCountTarget.textContent = `${selectedCount} of ${proposals.length} selected`;

    this.proposalsListTarget.innerHTML = proposals
      .map((p) => this._renderProposalRow(p))
      .join("");
  }

  _renderProposalRow(proposal) {
    if (proposal.editing) {
      return this._renderEditingRow(proposal);
    }
    return this._renderDisplayRow(proposal);
  }

  _renderDisplayRow(p) {
    const checkedAttr = p.selected ? "checked" : "";
    const selectedBorder = p.selected
      ? "border-blue-300 dark:border-blue-600 bg-blue-50/50 dark:bg-blue-900/10"
      : "border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800";

    return `
      <div data-proposal-row="${p.localId}"
           class="rounded-lg border ${selectedBorder} p-4 transition-colors">
        <div class="flex items-start gap-3">
          <input type="checkbox"
                 ${checkedAttr}
                 data-proposal-id="${p.localId}"
                 data-action="change->generations-new#toggleProposal"
                 class="mt-1 h-4 w-4 rounded border-gray-300 dark:border-gray-600
                        text-blue-600 focus:ring-blue-500 cursor-pointer"
                 aria-label="Select proposal">
          <div class="flex-1 min-w-0">
            <div class="mb-2">
              <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Front</span>
              <p class="text-sm text-gray-900 dark:text-gray-100 mt-0.5">${this._escapeHtml(p.front)}</p>
            </div>
            <div>
              <span class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Back</span>
              <p class="text-sm text-gray-700 dark:text-gray-300 mt-0.5">${this._escapeHtml(p.back)}</p>
            </div>
            ${p.sourceKind === "ai_edited" ? '<span class="inline-block mt-2 text-xs bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 px-2 py-0.5 rounded-full">Edited</span>' : ""}
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <button data-proposal-id="${p.localId}"
                    data-action="click->generations-new#startEdit"
                    class="text-sm text-blue-600 hover:text-blue-700 dark:text-blue-400 font-medium cursor-pointer">
              Edit
            </button>
            <button data-proposal-id="${p.localId}"
                    data-action="click->generations-new#rejectProposal"
                    class="text-sm text-red-600 hover:text-red-700 dark:text-red-400 font-medium cursor-pointer">
              Reject
            </button>
          </div>
        </div>
      </div>
    `;
  }

  _renderEditingRow(p) {
    const frontErrId = `${p.localId}-front-error`;
    const backErrId = `${p.localId}-back-error`;
    const frontError = p.errors.front
      ? `<p id="${frontErrId}" class="text-xs text-red-600 dark:text-red-400 mt-1" role="alert">${this._escapeHtml(p.errors.front)}</p>`
      : "";
    const backError = p.errors.back
      ? `<p id="${backErrId}" class="text-xs text-red-600 dark:text-red-400 mt-1" role="alert">${this._escapeHtml(p.errors.back)}</p>`
      : "";

    const frontInvalid = p.errors.front
      ? `aria-invalid="true" aria-describedby="${frontErrId}"`
      : "";
    const backInvalid = p.errors.back
      ? `aria-invalid="true" aria-describedby="${backErrId}"`
      : "";

    const frontLabelId = `${p.localId}-front-label`;
    const backLabelId = `${p.localId}-back-label`;

    return `
      <div data-proposal-row="${p.localId}"
           class="rounded-lg border border-blue-400 dark:border-blue-500 bg-blue-50 dark:bg-blue-900/20 p-4"
           role="group"
           aria-label="Edit proposal">
        <div class="space-y-3">
          <div>
            <label id="${frontLabelId}" class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Front</label>
            <input type="text"
                   data-field="front"
                   value="${this._escapeAttr(p.front)}"
                   maxlength="200"
                   aria-labelledby="${frontLabelId}"
                   ${frontInvalid}
                   class="w-full rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700
                          text-gray-900 dark:text-gray-100 text-sm px-3 py-2
                          focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            ${frontError}
          </div>
          <div>
            <label id="${backLabelId}" class="block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1">Back</label>
            <textarea data-field="back"
                      maxlength="500"
                      rows="3"
                      aria-labelledby="${backLabelId}"
                      ${backInvalid}
                      class="w-full rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700
                             text-gray-900 dark:text-gray-100 text-sm px-3 py-2
                             focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y">${this._escapeHtml(p.back)}</textarea>
            ${backError}
          </div>
          <div class="flex items-center gap-2 justify-end">
            <button data-proposal-id="${p.localId}"
                    data-action="click->generations-new#cancelEdit"
                    class="text-sm text-gray-600 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200
                           font-medium cursor-pointer px-3 py-1.5">
              Cancel
            </button>
            <button data-proposal-id="${p.localId}"
                    data-action="click->generations-new#saveEdit"
                    class="text-sm bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-md
                           px-3 py-1.5 cursor-pointer transition-colors">
              Save
            </button>
          </div>
        </div>
      </div>
    `;
  }

  // ── Private: Status Banner ──────────────────────────────

  _showStatus(kind, title, body, actionLabel = null, actionHref = null) {
    const banner = this.statusBannerTarget;
    banner.classList.remove("hidden");

    const kindStyles = {
      success:
        "bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-300 border border-green-200 dark:border-green-800",
      error:
        "bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-300 border border-red-200 dark:border-red-800",
      warning:
        "bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-300 border border-amber-200 dark:border-amber-800",
      info: "bg-blue-50 dark:bg-blue-900/20 text-blue-800 dark:text-blue-300 border border-blue-200 dark:border-blue-800",
    };

    const iconSvgs = {
      success:
        '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>',
      error:
        '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>',
      warning:
        '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 10-2 0 1 1 0 002 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>',
      info: '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/></svg>',
    };

    const inner = banner.querySelector("div");
    inner.className = `rounded-lg p-4 flex items-start gap-3 ${kindStyles[kind] || kindStyles.info}`;

    this.statusIconTarget.innerHTML = iconSvgs[kind] || iconSvgs.info;
    this.statusTitleTarget.textContent = title;
    this.statusBodyTarget.textContent = body;

    if (actionLabel && actionHref) {
      this.statusActionTarget.textContent = actionLabel;
      this.statusActionTarget.href = actionHref;
      this.statusActionTarget.classList.remove("hidden");
    } else {
      this.statusActionTarget.classList.add("hidden");
    }
  }

  _hideStatus() {
    this.statusBannerTarget.classList.add("hidden");
  }

  // ── Private: Field Error ────────────────────────────────

  _showFieldError(msg) {
    this.fieldErrorTarget.textContent = msg;
    this.fieldErrorTarget.classList.remove("hidden");
  }

  _clearFieldError() {
    this.fieldErrorTarget.classList.add("hidden");
    this.fieldErrorTarget.textContent = "";
  }

  // ── Private: Proposals ──────────────────────────────────

  _clearProposals() {
    this.state.proposals = [];
    this.proposalsSectionTarget.classList.add("hidden");
    this.proposalsListTarget.innerHTML = "";
  }

  // ── Private: Error Handling ─────────────────────────────

  _handleGenerateError(status, data) {
    const msg = mapApiError(status, data);

    if (status === 400) {
      this._showFieldError(msg.body);
    } else {
      this._showStatus(msg.kind, msg.title, msg.body);
    }
  }

  // ── Private: Helpers ────────────────────────────────────

  _csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  _escapeHtml(str) {
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
  }

  _escapeAttr(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }
}
