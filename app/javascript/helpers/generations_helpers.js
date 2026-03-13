/**
 * Domain helpers for the generations/new view.
 * Pure functions for validation, API error mapping, and source mapping.
 */

// ── Validation ────────────────────────────────────────────

const SOURCE_TEXT_MIN = 1000;
const SOURCE_TEXT_MAX = 10000;
const FRONT_MAX = 200;
const BACK_MAX = 500;

export function validateSourceText(text) {
  const trimmed = text.trim();
  if (trimmed.length < SOURCE_TEXT_MIN) {
    return `Source text must be at least ${SOURCE_TEXT_MIN.toLocaleString()} characters`;
  }
  if (trimmed.length > SOURCE_TEXT_MAX) {
    return `Source text must be at most ${SOURCE_TEXT_MAX.toLocaleString()} characters`;
  }
  return null;
}

export function validateProposal(front, back) {
  const errors = {};
  const f = front.trim();
  const b = back.trim();

  if (f.length < 1 || f.length > FRONT_MAX) {
    errors.front = `Front must be 1–${FRONT_MAX} characters`;
  }
  if (b.length < 1 || b.length > BACK_MAX) {
    errors.back = `Back must be 1–${BACK_MAX} characters`;
  }
  return errors;
}

// ── API Error → UiMessage mapping ─────────────────────────

export function mapApiError(status, data) {
  const message = data?.error?.message || "An unexpected error occurred";
  const code = data?.error?.code || "unknown";

  if (status === 422) {
    return {
      kind: "warning",
      code,
      title: "Duplicate",
      body: message,
    };
  }

  if (status === 400) {
    return {
      kind: "error",
      code,
      title: "Validation Error",
      body: message,
    };
  }

  if (status === 401) {
    return {
      kind: "error",
      code,
      title: "Unauthorized",
      body: "Authentication required. Please log in.",
    };
  }

  return {
    kind: "error",
    code,
    title: "Error",
    body: message,
  };
}

// ── Source mapping ─────────────────────────────────────────

/**
 * Determines the flashcard source based on whether it was edited.
 * AI proposals come as "ai-full" from the backend; we map to model enum values.
 */
export function resolveSource(
  originalFront,
  originalBack,
  currentFront,
  currentBack,
) {
  if (currentFront !== originalFront || currentBack !== originalBack) {
    return "ai_edited";
  }
  return "ai_generated";
}
