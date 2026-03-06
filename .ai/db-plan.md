# Plan bazy danych – 10x-cards MVP

## Encje i relacje

```
users (1) ──→ (N) sessions
users (1) ──→ (N) generations
users (1) ──→ (N) flashcards
generations (1) ──→ (N) flashcards         [nullable FK, ON DELETE SET NULL]
generations (1) ──→ (N) generation_error_logs [FK, ON DELETE CASCADE]
```

## Tabela `users`

| Kolumna           | Typ              | Ograniczenia                          |
|-------------------|------------------|---------------------------------------|
| `id`              | bigint           | PK                                    |
| `email_address`   | citext           | NOT NULL, UNIQUE                      |
| `password_digest` | string           | NULLABLE (Google SSO users)           |
| `provider`        | string           | NULLABLE (`"google"`)                 |
| `uid`             | string           | NULLABLE (Google id)                  |
| `first_name`      | string           | NULLABLE                              |
| `created_at`      | datetime         | NOT NULL                              |
| `updated_at`      | datetime         | NOT NULL                              |

**Indeksy:**
- UNIQUE on `email_address`
- UNIQUE on `(provider, uid)` WHERE `provider IS NOT NULL`

---

## Tabela `sessions` (Rails 8 native auth)

| Kolumna      | Typ      | Ograniczenia                                    |
|--------------|----------|-------------------------------------------------|
| `id`         | bigint   | PK                                              |
| `user_id`    | bigint   | FK → users, NOT NULL, ON DELETE CASCADE         |
| `ip_address` | string   | NULLABLE                                        |
| `user_agent` | string   | NULLABLE                                        |
| `created_at` | datetime | NOT NULL                                        |
| `updated_at` | datetime | NOT NULL                                        |

**Indeksy:**
- on `user_id`

---

## Tabela `generations`

| Kolumna                   | Typ      | Ograniczenia                                          |
|---------------------------|----------|-------------------------------------------------------|
| `id`                      | bigint   | PK                                                    |
| `user_id`                 | bigint   | FK → users, NOT NULL, ON DELETE CASCADE               |
| `source_text`             | text     | NOT NULL, CHECK(length BETWEEN 1000 AND 10000)        |
| `source_text_hash`        | string   | NOT NULL                                              |
| `source_text_length`      | integer  | NOT NULL                                              |
| `model`                   | string   | NOT NULL                                              |
| `generated_count`         | integer  | NOT NULL, DEFAULT 0                                   |
| `accepted_unedited_count` | integer  | NOT NULL, DEFAULT 0                                   |
| `accepted_edited_count`   | integer  | NOT NULL, DEFAULT 0                                   |
| `generation_duration`     | integer  | NOT NULL                                 |
| `created_at`              | datetime | NOT NULL                                              |
| `updated_at`              | datetime | NOT NULL                                              |

**Indeksy:**
- on `user_id`
- UNIQUE on `(user_id, source_text_hash)` — blokuje duplikaty tekstu źródłowego per użytkownik

---

## Tabela `flashcards`

| Kolumna         | Typ          | Ograniczenia                                              |
|-----------------|--------------|-----------------------------------------------------------|
| `id`            | bigint       | PK                                                        |
| `user_id`       | bigint       | FK → users, NOT NULL, ON DELETE CASCADE                   |
| `generation_id` | bigint       | FK → generations, NULLABLE, ON DELETE SET NULL             |
| `front`         | varchar(200) | NOT NULL, CHECK(char_length(front) > 0 AND char_length(front) <= 200)  |
| `back`          | varchar(500) | NOT NULL, CHECK(char_length(back) > 0 AND char_length(back) <= 500)    |
| `source`        | string       | NOT NULL, enum: `manual`, `ai_generated`, `ai_edited`     |
| `created_at`    | datetime     | NOT NULL                                                  |
| `updated_at`    | datetime     | NOT NULL                                                  |

**Indeksy:**
- on `user_id`
- on `generation_id`

---

## Tabela `generation_error_logs`

| Kolumna         | Typ      | Ograniczenia                                   |
|-----------------|----------|------------------------------------------------|
| `id`            | bigint   | PK                                             |
| `generation_id` | bigint   | FK → generations, NOT NULL, ON DELETE CASCADE  |
| `error_code`    | string   | NOT NULL                                       |
| `error_message` | text     | NOT NULL                                       |
| `occurred_at`   | datetime | NOT NULL                                       |
| `created_at`    | datetime | NOT NULL                                       |

**Indeksy:**
- on `generation_id`

---

## Diagram relacji

```
┌──────────┐       ┌────────────┐       ┌──────────────────────┐
│  users   │──1:N──│  sessions  │       │ generation_error_logs│
│          │       └────────────┘       └──────────┬───────────┘
│          │                                       │ N
│          │──1:N──┌──────────────┐──1:N───────────┘
│          │       │ generations  │
│          │       └──────┬───────┘
│          │              │ 1 (nullable)
│          │──1:N──┌──────┴───────┐
│          │       │  flashcards  │
└──────────┘       └──────────────┘
```

---

## Kluczowe zasady

1. **Autoryzacja:** Rails scoping (`current_user.flashcards`). Brak PostgreSQL RLS.
2. **Kaskadowe usuwanie:** `users` → CASCADE → `sessions`, `generations`, `flashcards`. `generations` → CASCADE → `generation_error_logs`. `generations` → SET NULL → `flashcards.generation_id`.
3. **Duplikaty tekstu:** Blokowane przez unique index `(user_id, source_text_hash)`. SHA-256 hash obliczany w modelu `Generation` before_validation.
4. **Propozycje AI:** W Solid Cache (TTL: 30 min), klucz: `generation:{generation_id}:proposals`.
5. **Liczniki:** `accepted_unedited_count` i `accepted_edited_count` aktualizowane jednorazowo (bulk) przy zatwierdzeniu partii.
6. **Extension PostgreSQL:** `citext` dla case-insensitive emaili.
7. **Rails enum (string):** Pole `source` w `flashcards` jako string enum: `manual`, `ai_generated`, `ai_edited`.
8. **Brak tabel SRS w MVP:** Algorytm powtórek poza zakresem. Tabele dodane w kolejnej iteracji.
9. **Usunięcie konta:** Natychmiastowe hard delete z kaskadowym usunięciem wszystkich powiązanych danych (RODO).
10. **Sortowanie fiszek:** Domyślnie `created_at DESC` z paginacją (20/stronę).
