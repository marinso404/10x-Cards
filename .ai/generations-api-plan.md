# API Endpoint Implementation Plan: POST /api/v1/generations

## 1. Przegląd punktu końcowego
Endpoint `POST /api/v1/generations` służy do utworzenia nowego procesu generowania propozycji fiszek na podstawie tekstu źródłowego użytkownika. Dla poprawnego wejścia tworzy rekord `Generation`, wywołuje usługę AI przez OpenRouter, zapisuje metadane generacji i zwraca listę propozycji fiszek. Implementacja powinna zwracać `201 Created`.

## 2. Szczegóły żądania
- **Metoda HTTP:** `POST`
- **URL:** `/api/v1/generations`
- **Query Params:** brak
- **Nagłówki:**
  - `Content-Type: application/json`
  - sesja/autentykacja Rails 8 (wymagany zalogowany użytkownik)
- **Parametry:**
  - **Wymagane:**
    - `source_text` (String, długość 1000..10000)
  - **Opcjonalne:** brak
- **Request Body (JSON):**

```json
{
  "source_text": "...1000-10000 chars..."
}
```

- **Wykorzystywane typy (DTO/Command):**
  - `Generations::CreateRequest` (obiekt wejściowy, walidacja requestu)
  - `Generations::CreateFromSourceText` (service object)
  - `Result` (`success?`, `data`, `errors`, `error_code`)
  - `Ai::OpenrouterClient` (adapter HTTP do OpenRouter)

## 3. Szczegóły odpowiedzi
- **201 Created** (sukces utworzenia):

```json
{
  "generation_id": 77,
  "flashcards_proposals": [
    {"id": "1", "front": "Generated Question", "back": "Generated Answer", "source": "ai-full"}
  ],
  "generated_count": 1
}
```

- **400 Bad Request** (błędny payload):

```json
{
  "error": {
    "code": "invalid_request",
    "message": "source_text must be between 1000 and 10000 characters"
  }
}
```

- **401 Unauthorized** (brak autoryzacji):

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

- **500 Internal Server Error** (AI/DB):

```json
{
  "error": {
    "code": "generation_failed",
    "message": "Generation failed"
  }
}
```

- **200 OK** i **404 Not Found**
  - nie są głównymi statusami tego endpointu tworzącego zasób,
  - pozostają częścią spójnego standardu API dla innych operacji (`GET`) i nieistniejących ścieżek.

## 4. Przepływ danych
1. Klient wysyła `POST /api/v1/generations` z `source_text`.
2. Kontroler API (`Api::V1::GenerationsController#create`) wymusza autoryzację użytkownika.
3. Kontroler waliduje payload technicznie (`strong params`) i przekazuje dane do `Generations::CreateFromSourceText`.
4. Serwis:
   - normalizuje `source_text` (`strip`),
   - wylicza `source_text_hash` (np. SHA256),
   - tworzy rekord `Generation` z początkowymi metrykami,
   - wywołuje `Ai::OpenrouterClient`,
   - mapuje odpowiedź AI do listy propozycji,
   - aktualizuje `generated_count`, `generation_duration`, `model`.
5. Kontroler zwraca `201` z `generation_id`, `flashcards_proposals`, `generated_count`.
6. W przypadku błędu AI/DB serwis zapisuje wpis do `generation_error_logs` i zwraca błąd domenowy, a kontroler mapuje go na `500`.

## 5. Względy bezpieczeństwa
- **Uwierzytelnianie i autoryzacja:** wymagany zalogowany użytkownik (`401` przy braku sesji).
- **Kontrola wejścia:** whitelist pól, limit długości `source_text`, odrzucanie niepoprawnego JSON.
- **Ochrona sekretów:** klucz OpenRouter wyłącznie po stronie serwera (`credentials`/ENV), filtrowanie logów (`filter_parameter_logging`).
- **Odporność na prompt injection:** twardy kontrakt odpowiedzi AI, walidacja struktury i typów pól `front/back/source`.
- **Ograniczanie nadużyć:** limit requestów per użytkownik/IP (rack-attack lub middleware), timeouty HTTP i limity retriable.
- **Spójność danych:** unikalny indeks `(user_id, source_text_hash)` jako ochrona przed duplikatami i wyścigami.

## 6. Obsługa błędów
- **Mapowanie błędów aplikacyjnych:**
  - `invalid_request` → `400`
  - `unauthorized` → `401`
  - `generation_failed` / `ai_error` / `db_error` → `500`
- **Strategia logowania do `generation_error_logs`:**
  - logować błędy AI/DB, gdy istnieje `generation_id`,
  - zapisywać: `generation_id`, `error_code`, bezpieczny `error_message`, `occurred_at`.
- **Błędy walidacyjne przed utworzeniem `Generation`:**
  - zwracać `400`,
  - bez wpisu do `generation_error_logs` (wymagane FK).
- **Fallback globalny:** `rescue_from StandardError` w warstwie API z generycznym komunikatem i `500`.

## 7. Wydajność
- Użycie serwisu z pojedynczą transakcją DB dla spójności zapisu metadanych.
- Minimalizacja payloadu odpowiedzi (zwracane tylko pola kontraktowe).
- Timeouty i kontrola retry dla OpenRouter, aby ograniczyć blokowanie requestów.
- Deduplikacja przez `source_text_hash` zmniejszająca koszt powtórnych wywołań AI.
- Pomiar `generation_duration` (ms) i telemetryka błędów do monitorowania SLA.
- W kolejnym kroku skalowania: opcjonalne przeniesienie wywołań AI do `Solid Queue` (bez Redis) przy zachowaniu kontraktu API.

## 8. Kroki implementacji
1. Dodać namespace i trasę API v1 dla `POST /api/v1/generations` w `config/routes.rb`.
2. Utworzyć `Api::V1::BaseController` (jeśli brak) z obsługą autoryzacji i wspólnym formatem błędów JSON.
3. Dodać `Api::V1::GenerationsController#create` z `strong params`, mapowaniem `Result` → statusy (`201/400/401/500`).
4. Zaimplementować `Generations::CreateRequest` (walidacje wejścia) i `Generations::CreateFromSourceText` (orchestracja biznesowa).
5. Zaimplementować/uzupełnić `Ai::OpenrouterClient` z timeoutami, obsługą błędów i walidacją struktury odpowiedzi.
6. Uzupełnić model `Generation` o walidacje spójne z DB (`length`, `presence`, unikalność hash per user).
7. Dodać mechanizm logowania błędów do `generation_error_logs` (helper/serwis `Generations::ErrorLogger`).
8. Zaimplementować serializację odpowiedzi sukcesu (`generation_id`, `flashcards_proposals`, `generated_count`) bez nadmiarowych pól.
9. Dodać testy:
   - request specs (`201`, `400`, `401`, `500`),
   - service specs (sukces, timeout AI, invalid AI response, duplicate hash),
   - model specs (`Generation`, `GenerationErrorLog`).
10. Dodać instrumentację i logowanie (czas generacji, kod błędu, model AI), zweryfikować brak logowania sekretów.
11. Zaktualizować dokumentację API w `README.md`/`docs/` oraz dopisać wpis do `CHANGELOG.md`.
