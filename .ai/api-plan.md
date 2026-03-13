# REST API Plan

## Assumptions
- API is versioned under `/api/v1`.
- Authentication uses Rails 8 native session-based auth (cookie session backed by `sessions` table).
- Google SSO callback flow is handled server-side; API exposes status/session endpoints for SPA-like interactions.
- Study scheduling algorithm is integrated via a service object (external library), without dedicated SRS tables in MVP.
- All list endpoints are user-scoped (`current_user`) and return paginated data.

## 1. Resources
- **User** → `users`
- **Session** → `sessions`
- **Generation** → `generations`
- **Flashcard** → `flashcards`
- **GenerationErrorLog** (read-only user scope) → `generation_error_logs`
- **StudySession** (virtual resource, algorithm-driven) → no dedicated table in MVP

---

## 2. Endpoints

## 2.1 Auth & Account

### 2.1.1 Register
- **HTTP Method:** `POST`
- **URL:** `/api/v1/auth/registrations`
- **Description:** Create account and sign in user.
- **Query Params:** none
- **Request JSON:**
```json
{
  "email_address": "user@example.com",
  "password": "StrongPassw0rd!",
  "password_confirmation": "StrongPassw0rd!"
}
```
- **Success Response JSON (201):**
```json
{
  "data": {
    "user": {
      "id": 1,
      "email_address": "user@example.com",
      "first_name": null,
      "provider": null,
      "created_at": "2026-03-06T12:00:00Z"
    }
  }
}
```
- **Success Codes:** `201 Created`
- **Error Codes:**
  - `422 Unprocessable Entity` (validation errors)
  - `409 Conflict` (email already exists)

### 2.1.2 Login (password)
- **HTTP Method:** `POST`
- **URL:** `/api/v1/auth/sessions`
- **Description:** Authenticate with email/password and create user session.
- **Query Params:** none
- **Request JSON:**
```json
{
  "email_address": "user@example.com",
  "password": "StrongPassw0rd!"
}
```
- **Success Response JSON (201):**
```json
{
  "data": {
    "session": {
      "id": 55,
      "user_id": 1,
      "created_at": "2026-03-06T12:10:00Z"
    },
    "user": {
      "id": 1,
      "email_address": "user@example.com"
    }
  }
}
```
- **Success Codes:** `201 Created`
- **Error Codes:**
  - `401 Unauthorized` (invalid credentials)
  - `423 Locked` (optional temporary lock after repeated failures)

### 2.1.3 Logout
- **HTTP Method:** `DELETE`
- **URL:** `/api/v1/auth/sessions/current`
- **Description:** Delete current session.
- **Query Params:** none
- **Request JSON:** none
- **Success Response JSON (200):**
```json
{
  "message": "Signed out"
}
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `401 Unauthorized` (no active session)

### 2.1.4 Current user
- **HTTP Method:** `GET`
- **URL:** `/api/v1/auth/me`
- **Description:** Returns authenticated user profile.
- **Query Params:** none
- **Request JSON:** none
- **Success Response JSON (200):**
```json
{
  "data": {
    "user": {
      "id": 1,
      "email_address": "user@example.com",
      "first_name": "Martin",
      "provider": "google"
    }
  }
}
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `401 Unauthorized`

### 2.1.5 Google SSO start
- **HTTP Method:** `GET`
- **URL:** `/api/v1/auth/google`
- **Description:** Start OAuth flow (redirect endpoint).
- **Query Params:** optional `redirect_to`
- **Request JSON:** none
- **Success Response:** `302 Found` redirect to provider
- **Error Codes:** `400 Bad Request`

### 2.1.6 Google SSO callback
- **HTTP Method:** `GET`
- **URL:** `/api/v1/auth/google/callback`
- **Description:** Complete OAuth flow, create/link user, start session.
- **Success Response:** `302 Found` to frontend URL
- **Error Codes:**
  - `401 Unauthorized`
  - `422 Unprocessable Entity`

### 2.1.7 Delete account (GDPR)
- **HTTP Method:** `DELETE`
- **URL:** `/api/v1/account`
- **Description:** Hard-delete user and all related data (cascade).
- **Query Params:** none
- **Request JSON:**
```json
{
  "password": "StrongPassw0rd!"
}
```
- **Success Response JSON (200):**
```json
{
  "message": "Account deleted"
}
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `401 Unauthorized`
  - `422 Unprocessable Entity` (password confirmation required for local accounts)

---

## 2.2 Flashcards

### 2.2.1 List flashcards
- **HTTP Method:** `GET`
- **URL:** `/api/v1/flashcards`
- **Description:** Paginated list of user flashcards.
- **Query Params:**
  - `page` (default: `1`)
  - `per_page` (default: `20`, max: `100`)
  - `source` (`manual|ai_generated|ai_edited`)
  - `generation_id`
  - `sort` (`created_at_desc` default, `created_at_asc`, `updated_at_desc`)
- **Request JSON:** none
- **Success Response JSON (200):**
```json
{
  "data": [
    {
      "id": 101,
      "front": "What is HTTP 201?",
      "back": "Created",
      "source": "manual",
      "generation_id": null,
      "created_at": "2026-03-06T12:20:00Z",
      "updated_at": "2026-03-06T12:20:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total_count": 135,
    "total_pages": 7
  }
}
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `400 Bad Request` (invalid filter/sort)
  - `401 Unauthorized`

### 2.2.2 Show flashcard
- **HTTP Method:** `GET`
- **URL:** `/api/v1/flashcards/:id`
- **Description:** Return single flashcard.
- **Success Response JSON (200):**
```json
{
  "data": {
    "id": 101,
    "front": "What is HTTP 201?"
    "back": "Created",
    "source": "manual",
    "generation_id": null,
    "created_at": "2026-03-06T12:20:00Z",
    "updated_at": "2026-03-06T12:20:00Z"
  }
}
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `401 Unauthorized`
  - `404 Not Found`

### 2.2.3 Create flashcard (manual)
- **HTTP Method:** `POST`
- **URL:** `/api/v1/flashcards`
- **Description:** Create manual flashcard.
- **Request JSON:**
```json
{
  "front": "Question text",
  "back": "Answer text"
}
```
- **Success Response JSON (201):**
```json
{
  "data": {
    "id": 102,
    "front": "Question text",
    "back": "Answer text",
    "source": "manual",
    "generation_id": null
  }
}
```
- **Success Codes:** `201 Created`
- **Error Codes:**
  - `401 Unauthorized`
  - `422 Unprocessable Entity` (`front`/`back` invalid)
  #### 2.2.3.a Bulk create flashcards (same endpoint)

  - **HTTP Method:** `POST`
  - **URL:** `/api/v1/flashcards`
  - **Description:** Endpoint accepts batch creation to support manual cards and AI acceptance flows (`ai_generated`, `ai_edited`).
  - **Request JSON (bulk):**
  ```json
  {
    "flashcards": [
      {
        "front": "What is REST?",
        "back": "Architectural style for distributed systems",
        "source": "ai_generated",
        "generation_id": 77
      },
      {
        "front": "Updated question",
        "back": "Updated answer",
        "source": "ai_edited",
        "generation_id": 77
      },
      {
        "front": "Manual question",
        "back": "Manual answer",
        "source": "manual"
      }
    ]
  }
  ```
  - **Rules:**
    - `flashcards` array size: `1..100` per request.
    - `front` maxiumum length 200 characters
    - `back` maxiumum length 500 characters
    - Operation is atomic (all-or-nothing transaction).
    - `source` allowed values: `manual|ai_generated|ai_edited`.
    - `generation_id` is required for `ai_generated` and `ai_edited`, optional for `manual`.
  - **Success Response JSON (201):**
  ```json
  {
    "data": {
      "created_flashcards": [
        { "id": 301, "source": "ai_generated", "generation_id": 77 },
        { "id": 302, "source": "ai_edited", "generation_id": 77 },
        { "id": 303, "source": "manual", "generation_id": null }
      ],
      "count": 3
    }
  }
  ```
  - **Error Codes:**
    - `400 Bad Request` (invalid payload shape)
    - `401 Unauthorized`
    - `404 Not Found` (`generation_id` not in user scope)
    - `422 Unprocessable Entity` (any item invalid)
    - `413 Payload Too Large` (batch limit exceeded)

### 2.2.4 Update flashcard
- **HTTP Method:** `PATCH`
- **URL:** `/api/v1/flashcards/:id`
- **Description:** Update `front` and/or `back`.
- **Request JSON:**
```json
{
  "front": "Updated question",
  "back": "Updated answer"
}
```
- **Success Response JSON (200):**
```json
{
  "data": {
    "id": 102,
    "front": "Updated question",
    "back": "Updated answer",
    "source": "manual"
  }
}

- **Rules:**
    - `front` maxiumum length 200 characters
    - `back` maxiumum length 500 characters
    - `source` Must be one of `ai_edited` or `manual`
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `401 Unauthorized`
  - `404 Not Found`
  - `422 Unprocessable Entity`

### 2.2.5 Delete flashcard
- **HTTP Method:** `DELETE`
- **URL:** `/api/v1/flashcards/:id`
- **Description:** Permanently remove flashcard.
- **Request JSON:** none
- **Success Response JSON (200):**
```json
{
  "message": "Flashcard deleted"
}
```
- **Success Codes:** `200 OK`
- **Error Codes:**
  - `401 Unauthorized`
  - `404 Not Found`

---

## 2.3 Generations (AI)

### 2.3.1 Create generation job
- **HTTP Method:** `POST`
- **URL:** `/api/v1/generations`
- **Description:** Submit source text for AI flashcard suggestions.
- **Query Params:** none
- **Request JSON:**
```json
{
  "source_text": "...1000-10000 chars...",
}
```
- **Business Logic**:
  - Call the AI service to generate flashcards proposals
- **Success Response JSON (202):**
```json
{
  "generation_id": 77,
  "flashcards_proposals": [
    {"id": "1", "front": "Generated Question", "back": "Generated Answer", "source": "ai-full"}
  ],
  "generated_count": 1,
}
```
- **Success Codes:** `201 Pomyslne utworzenie generacji`
- **Error Codes:**
  - `400 Bad Request` (invalid payload)
  - `500: AI service errors or database` (logs recorded in `generation_error_logs`)

### 2.3.2 List generations
- **HTTP Method:** `GET`
- **URL:** `/api/v1/generations`
- **Description:** Paginated generation history for current user.
- **Query Params:**
  - `page`, `per_page`
  - `sort` (`created_at_desc` default, `created_at_asc`)
- **Success Response JSON (200):**
```json
{
  "data": [
    {
      "id": 77,
      "source_text_length": 2432,
      "model": "openai/gpt-4o-mini",
      "generated_count": 10,
      "accepted_unedited_count": 4,
      "accepted_edited_count": 3,
      "generation_duration": 1840,
      "created_at": "2026-03-06T12:30:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total_count": 14,
    "total_pages": 1
  }
}
```
- **Success Codes:** `200 OK`
- **Error Codes:** `401 Unauthorized`, `400 Bad Request`

### 2.3.3 Show generation
- **HTTP Method:** `GET`
- **URL:** `/api/v1/generations/:id`
- **Description:** Generation details with counters and status.
- **Success Response JSON (200):**
```json
{
  "data": {
    "id": 77,
    "source_text_length": 2432,
    "model": "openai/gpt-4o-mini",
    "generated_count": 10,
    "accepted_unedited_count": 4,
    "accepted_edited_count": 3,
    "generation_duration": 1840,
    "flashcards_proposals": [
      {"id": "1", "front": "Generated Question", "back": "Generated Answer", "source": "ai-full"}
    ],
    "created_at": "2026-03-06T12:30:00Z"
  }
}
```
- **Success Codes:** `200 OK`
- **Error Codes:** `401 Unauthorized`, `404 Not Found`


### 2.3.6 Generation errors list (optional UI diagnostics)
- **HTTP Method:** `GET`
- **URL:** `/api/v1/generations/:id/errors`
- **Description:** List logged generation errors.
- **Success Response JSON (200):**
```json
{
  "data": [
    {
      "id": 1,
      "error_code": "openrouter_timeout",
      "error_message": "Upstream timeout",
      "occurred_at": "2026-03-06T12:31:10Z"
    }
  ]
}
```
- **Success Codes:** `200 OK`
- **Error Codes:** `401 Unauthorized`, `404 Not Found`

---



## 3. Authentication and Authorization
- Use Rails 8 native authentication with encrypted, HttpOnly, Secure session cookie.
- Every endpoint except auth registration/login/OAuth callback requires authenticated session.
- Authorization rule: always scope resources by `current_user` (`current_user.flashcards`, `current_user.generations`, etc.).
- Reject cross-tenant access with `404 Not Found` (resource exists but does not belong to user).
- Session lifecycle stored in `sessions` table (`user_id` FK, cascade delete).
- Optional CSRF strategy:
  - Browser clients: standard Rails CSRF protection enabled.
  - Non-browser API clients (if introduced later): separate token strategy.

---

## 4. Validation and Business Logic

### 4.1 Validation rules by resource

#### User
- `email_address`: required, unique, case-insensitive (`citext`).
- `password_digest`: required for local auth users; nullable for Google SSO users.
- `provider`/`uid`: unique pair when provider present.

#### Session
- `user_id`: required and must exist.

#### Generation
- `user_id`: required.
- `source_text`: required, length `1000..10000`.
- `source_text_hash`: required; SHA-256 computed before validation.
- `source_text_hash` uniqueness per user: unique index `(user_id, source_text_hash)`.
- `source_text_length`: required and consistent with `source_text`.
- `model`: required.
- `generated_count`, `accepted_unedited_count`, `accepted_edited_count`: integers, default `0`, non-negative.
- `generation_duration`: required integer once generation completes.

#### Flashcard
- `user_id`: required.
- `generation_id`: optional; if generation deleted then set `NULL`.
- `front`: required, trimmed, length `1..200`.
- `back`: required, trimmed, length `1..500`.
- `source`: required enum string (`manual`, `ai_generated`, `ai_edited`).

#### GenerationErrorLog
- `generation_id`: required.
- `error_code`, `error_message`: required.
- `occurred_at`: required timestamp.

### 4.2 Business logic mapping
- **AI generation flow**
  1. `POST /generations` validates input and deduplicates by hash.
  2. Call the AI service to generate flashcards proposals
  3. Record generation metadata(model, generated_count, duration) and presist generated flashcards proposals
  4. Log any errors in `generation_error_logs` for auditing and debugging

- **Manual flashcard management**
  - `POST /flashcards`, `PATCH /flashcards/:id`, `DELETE /flashcards/:id`, `GET /flashcards`.

- **Data ownership and privacy**
  - Every DB query is user-scoped; no access to other users' flashcards/generations.

- **Account deletion (GDPR)**
  - `DELETE /account` performs hard delete of user.
  - DB cascades remove sessions, generations, flashcards, and generation error logs.


### 4.3 Pagination, filtering, sorting standards
- Pagination: `page`, `per_page` with defaults `1` and `20`, max `100`.
- Standard response `meta`: `page`, `per_page`, `total_count`, `total_pages`.
- Default sort: `created_at desc` for list endpoints.
- Reject unsupported filters/sorts with `400 Bad Request`.

### 4.4 Security and resilience measures
- Rate limiting:
  - Strict limits on `POST /generations` (per user + per IP).
  - Moderate limits on auth endpoints (`/auth/sessions`, OAuth callback).
- Input hardening:
  - Strong parameter whitelisting.
  - Trim and normalize text fields before validation.
  - Output encoding handled by JSON serializers.
- Transport and session security:
  - HTTPS only, Secure cookies, HttpOnly, SameSite=Lax/Strict.
- Auditability and failures:
  - Persist AI failures in `generation_error_logs`.
  - Return stable machine-readable error payload:
```json
{
  "error": {
    "code": "validation_error",
    "message": "front is too long",
    "details": {
      "front": ["must be at most 200 characters"]
    }
  }
}
```

### 4.5 Performance considerations from schema and stack
- Use DB indexes in list/detail queries:
  - `flashcards(user_id, created_at)` for default list sorting.
  - `generations(user_id, created_at)` for generation history.
  - Unique hash index for fast duplicate detection.
- Prevent N+1 by eager loading related objects where needed (`generation` for flashcards view, counters summary).
