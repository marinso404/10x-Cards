import { Controller } from "@hotwired/stimulus";

/**
 * Manages proposal card list: select all, deselect all, save selected, discard.
 * Uses outlets to communicate with individual proposal-card controllers and status-banner.
 */
export default class extends Controller {
  static outlets = ["proposal-card", "status-banner"];

  static targets = [
    "proposalCount",
    "bulkCount",
    "cardsList",
    "saveBtn",
    "saveSpinner",
    "discardBtn",
  ];

  static values = {
    flashcardsUrl: String,
    generationId: Number,
    countTemplate: String,
    saveSuccessTitle: String,
    saveSuccessBody: String,
    saveErrorBody: String,
    networkErrorBody: String,
    noSelectionTitle: String,
    noSelectionBody: String,
    discardedTitle: String,
    discardedBody: String,
    errorTitle: String,
  };

  // ── Outlet callbacks ──

  proposalCardOutletConnected() {
    this.updateCount();
  }

  proposalCardOutletDisconnected() {
    this.updateCount();
    if (this.proposalCardOutlets.length === 0) {
      this.element.classList.add("hidden");
    }
  }

  // ── Actions ──

  selectAll() {
    this.proposalCardOutlets.forEach((card) => card.select());
    this.updateCount();
  }

  deselectAll() {
    this.proposalCardOutlets.forEach((card) => card.deselect());
    this.updateCount();
  }

  updateCount() {
    const total = this.proposalCardOutlets.length;
    const selected = this.proposalCardOutlets.filter(
      (c) => c.isSelected,
    ).length;
    const text = this.countTemplateValue
      .replace("{selected}", selected)
      .replace("{total}", total);

    if (this.hasProposalCountTarget) this.proposalCountTarget.textContent = text;
    if (this.hasBulkCountTarget) this.bulkCountTarget.textContent = text;
  }

  async saveSelected() {
    const selected = this.proposalCardOutlets.filter((c) => c.isSelected);

    if (selected.length === 0) {
      this._showBanner(
        "warning",
        this.noSelectionTitleValue,
        this.noSelectionBodyValue,
      );
      return;
    }

    this._setSaving(true);

    try {
      const payload = {
        flashcards: selected.map((card) => ({
          ...card.toPayload(),
          generation_id: this.generationIdValue,
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
        this._showBanner(
          "success",
          this.saveSuccessTitleValue,
          this.saveSuccessBodyValue.replace("{count}", count),
        );
      } else {
        this._showBanner(
          "error",
          this.errorTitleValue,
          this.saveErrorBodyValue,
        );
      }
    } catch {
      this._showBanner("error", this.errorTitleValue, this.networkErrorBodyValue);
    } finally {
      this._setSaving(false);
    }
  }

  discardAll() {
    this._clearProposals();
    this._showBanner(
      "info",
      this.discardedTitleValue,
      this.discardedBodyValue,
    );
  }

  // ── Private ──

  _setSaving(flag) {
    this.saveBtnTarget.disabled = flag;
    this.discardBtnTarget.disabled = flag;
    this.saveSpinnerTarget.classList.toggle("hidden", !flag);
  }

  _clearProposals() {
    this.cardsListTarget.innerHTML = "";
    this.element.classList.add("hidden");
  }

  _showBanner(kind, title, body) {
    if (this.hasStatusBannerOutlet) {
      this.statusBannerOutlet.show(kind, title, body);
    }
  }

  _csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }
}
