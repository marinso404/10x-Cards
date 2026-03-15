# Plan implementacji usługi OpenRouter (Rails 8 + Hotwire)

## 1. Opis usługi

Usługa ma zapewnić stabilną, bezpieczną i testowalną integrację z OpenRouter API do generowania treści LLM (w tym fiszek i rozszerzalnie czatów), zgodnie z architekturą Rails 8 Omakase: Service Objects + `Result`, PostgreSQL, Solid Queue/Cache/Cable, Hotwire po stronie UI.

### Kluczowe komponenty i cele

1. **OpenRouter Client (warstwa HTTP)**  
   Cel: pojedynczy punkt komunikacji z API OpenRouter (request/response, timeout, retry, mapowanie błędów).
2. **Prompt Builder (warstwa kontraktu wejścia)**  
   Cel: spójne budowanie `system` i `user` messages oraz metadanych wywołania.
3. **Response Format Builder (JSON Schema)**  
   Cel: wymuszenie odpowiedzi strukturalnej (`response_format`) i minimalizacja halucynacji formatu.
4. **Response Parser & Validator**  
   Cel: walidacja odpowiedzi modelu względem schematu + normalizacja do domeny aplikacji.
5. **Use Case Service (np. `Generations::GenerateFlashcards`)**  
   Cel: orkiestracja przepływu biznesowego (walidacja wejścia, wywołanie klienta, zapis do DB, zwrot `Result`).
6. **Error Taxonomy + Logging/Auditing**  
   Cel: przewidywalna obsługa awarii i diagnostyka (`GenerationErrorLog`, logi strukturalne).
7. **Asynchroniczne przetwarzanie (Solid Queue)**  
   Cel: przeniesienie dłuższych wywołań LLM do jobów, by nie blokować requestów HTTP.
8. **Konfiguracja i bezpieczeństwo sekretów**  
   Cel: bezpieczne przechowywanie klucza API oraz kontrola kosztu/modelu.

### Szczegóły komponentów: funkcjonalność, wyzwania, rozwiązania

1. **OpenRouter Client**
   - Funkcjonalność: buduje payload OpenRouter, wykonuje POST do endpointu chat/completions, obsługuje timeout/retry, zwraca surową odpowiedź lub błąd domenowy.
   - Wyzwania:
     1. Niestabilność sieci i timeouty.
     2. Niejednorodne błędy HTTP i limity dostawcy.
     3. Trudna diagnostyka bez spójnego kontekstu.
   - Rozwiązania:
     1. Ustalić twarde timeouty (connect/read/write) oraz retry tylko dla błędów przejściowych.
     2. Wprowadzić mapowanie statusów API -> `error_code` domenowe (`rate_limited`, `provider_unavailable`, `invalid_request`).
     3. Dodać korelację żądań (`request_id`, `generation_id`, `user_id`) i logi strukturalne.

2. **Prompt Builder**
   - Funkcjonalność: generuje komunikaty `system`/`user` na bazie kontekstu domeny (np. język, liczba wyników, ograniczenia treści).
   - Wyzwania:
     1. Rozjazd promptów między feature’ami.
     2. Wstrzykiwanie niepożądanych instrukcji przez input użytkownika.
   - Rozwiązania:
     1. Utrzymywać szablony promptów centralnie i wersjonować je.
     2. Oddzielić instrukcje systemowe od danych użytkownika; stosować delimitery i ograniczenia długości wejścia.

3. **Response Format Builder (JSON Schema)**
   - Funkcjonalność: dostarcza `response_format` wymagający poprawnego JSON zgodnego z kontraktem.
   - Wyzwania:
     1. Model zwraca tekst zamiast poprawnego JSON.
     2. JSON częściowo poprawny, ale niezgodny semantycznie.
   - Rozwiązania:
     1. Użyć `strict: true` i prostego, jednoznacznego schematu.
     2. Walidować odpowiedź po stronie serwera i zwracać błąd walidacji z możliwością kontrolowanego retry.

4. **Response Parser & Validator**
   - Funkcjonalność: wyciąga treść z odpowiedzi OpenRouter, parsuje JSON, waliduje schema-level i domain-level (np. długości pól).
   - Wyzwania:
     1. Zmienność formatu odpowiedzi dostawcy.
     2. Niskiej jakości treści mimo poprawnego JSON.
   - Rozwiązania:
     1. Izolować parser dostawcy od logiki domenowej; stosować adaptory.
     2. Dodać walidacje domenowe i filtrowanie przed zapisem do DB.

5. **Use Case Service**
   - Funkcjonalność: realizuje flow biznesowy i zwraca `Result.success`/`Result.failure`.
   - Wyzwania:
     1. Mieszanie odpowiedzialności (HTTP, walidacja, zapis).
     2. Niespójny interfejs błędów między serwisami.
   - Rozwiązania:
     1. Rozdzielić warstwy: Use Case (orkiestracja), Client (transport), Parser (format), Repo (persistencja).
     2. Ustandaryzować `error_code` i kontrakt `Result` w całym module.

6. **Error Taxonomy + Logging/Auditing**
   - Funkcjonalność: centralny katalog błędów i zapis szczegółów do `GenerationErrorLog` bez wycieku sekretów.
   - Wyzwania:
     1. Brak spójności kodów błędów utrudnia UI i monitoring.
     2. Ryzyko logowania danych wrażliwych.
   - Rozwiązania:
     1. Ustalić zamknięty słownik błędów i mapowanie na HTTP status.
     2. Redagować logi (maskowanie tokenów, skracanie payloadów).

7. **Asynchroniczne przetwarzanie (Solid Queue)**
   - Funkcjonalność: job wykonuje wywołanie OpenRouter i emituje wynik do UI (np. Turbo Stream) lub zapisuje gotowe propozycje.
   - Wyzwania:
     1. Duże opóźnienie LLM względem timeoutu requestu web.
     2. Powtórzenia jobów i idempotencja.
   - Rozwiązania:
     1. Dla cięższych zadań używać jobów + statusów generacji w DB.
     2. Wprowadzić klucz idempotencji i warunki „already processed”.

8. **Konfiguracja i bezpieczeństwo sekretów**
   - Funkcjonalność: konfiguracja modelu domyślnego, limitów tokenów, temperatury i kluczy API.
   - Wyzwania:
     1. Wyciek klucza API.
     2. Niekontrolowane koszty przez zły model/parametry.
   - Rozwiązania:
     1. Trzymać sekret wyłącznie po stronie serwera (Rails credentials/env), nigdy w JS/HTML.
     2. Dodać whitelistę modeli i limity parametrów per use case.

### Integracja wymagań OpenRouter API (z przykładami)

1. **Komunikat systemowy (`system message`)**
   - Podejścia:
     1. Szablon stały per use case (najbezpieczniejszy).
     2. Szablon parametryzowany (język, poziom szczegółowości, liczba elementów).
   - Przykład:

```json
{
  "role": "system",
  "content": "Jesteś asystentem edukacyjnym. Generuj fiszki zwięźle, bez treści spoza źródła. Zwracaj wyłącznie JSON zgodny ze schematem."
}
```

2. **Komunikat użytkownika (`user message`)**
   - Podejścia:
     1. Przekazywanie surowego tekstu źródłowego z delimitacją.
     2. Dodanie metadanych zadania (język, liczba fiszek, poziom trudności) poza samą treścią.
   - Przykład:

```json
{
  "role": "user",
  "content": "Utwórz 5 fiszek na podstawie poniższego tekstu.\n---\n<source_text>...treść użytkownika...</source_text>\n---"
}
```

3. **Ustrukturyzowane odpowiedzi (`response_format`)**
   - Podejścia:
     1. Jeden schemat JSON dla jednego use case (np. fiszki).
     2. Osobne schematy dla różnych use case’ów (fiszki, streszczenie, quiz).
   - Przykład (wzorzec docelowy):

```json
{
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "flashcards_response",
      "strict": true,
      "schema": {
        "type": "object",
        "additionalProperties": false,
        "required": ["flashcards"],
        "properties": {
          "flashcards": {
            "type": "array",
            "minItems": 1,
            "maxItems": 20,
            "items": {
              "type": "object",
              "additionalProperties": false,
              "required": ["front", "back", "source"],
              "properties": {
                "front": { "type": "string", "minLength": 3, "maxLength": 300 },
                "back": { "type": "string", "minLength": 3, "maxLength": 1000 },
                "source": { "type": "string", "enum": ["ai-full"] }
              }
            }
          }
        }
      }
    }
  }
}
```

4. **Nazwa modelu (`model`)**
   - Podejścia:
     1. Konfiguracja globalna z możliwością nadpisania per use case.
     2. Strategia fallback (model primary -> backup).
   - Przykład:

```json
{ "model": "openai/gpt-4.1-mini" }
```

5. **Parametry modelu (`temperature`, `max_tokens`, itp.)**
   - Podejścia:
     1. Profile parametrów per use case (deterministyczny dla ekstrakcji, kreatywny dla ideacji).
     2. Twarde limity kosztowe i jakościowe po stronie backendu.
   - Przykład:

```json
{
  "temperature": 0.2,
  "max_tokens": 1200,
  "top_p": 0.9
}
```

6. **Przykładowy pełny payload (minimalny, produkcyjny)**

```json
{
  "model": "openai/gpt-4.1-mini",
  "messages": [
    {
      "role": "system",
      "content": "Jesteś asystentem edukacyjnym. Zwracaj wyłącznie JSON zgodny ze schematem."
    },
    {
      "role": "user",
      "content": "Wygeneruj 5 fiszek z tekstu: <source_text>...</source_text>"
    }
  ],
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "flashcards_response",
      "strict": true,
      "schema": {
        "type": "object",
        "required": ["flashcards"],
        "properties": {
          "flashcards": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["front", "back", "source"],
              "properties": {
                "front": { "type": "string" },
                "back": { "type": "string" },
                "source": { "type": "string", "enum": ["ai-full"] }
              }
            }
          }
        }
      }
    }
  },
  "temperature": 0.2,
  "max_tokens": 1200
}
```

## 2. Opis konstruktora

Docelowa klasa: `Ai::OpenrouterClient` (zastępuje obecny mock).

### Konstruktor (zależności i konfiguracja)

- `api_key` (wymagane): pobierane z `Rails.application.credentials` lub ENV.
- `http_client` (opcjonalne): wstrzykiwany adapter HTTP dla testowalności.
- `base_url` (opcjonalne): domyślnie endpoint OpenRouter.
- `timeout_config` (opcjonalne): connect/read/write timeout.
- `default_model` (opcjonalne): model domyślny zgodny z polityką kosztu.
- `default_params` (opcjonalne): bezpieczne wartości `temperature`, `max_tokens`, `top_p`.
- `logger` (opcjonalne): logger strukturalny Rails.

Konstruktor powinien walidować kompletność konfiguracji na starcie i fail-fast przy brakującym `api_key`.

## 3. Publiczne metody i pola

### Publiczne metody

1. `generate_chat(system_message:, user_message:, response_schema:, model: nil, model_params: {})`
   - Cel: główna metoda do wywołania OpenRouter dla jednego zadania.
   - Wejście: znormalizowane message + schema.
   - Wyjście: `Result.success(data: { content:, parsed:, model:, usage: })` albo `Result.failure(...)`.

2. `generate_flashcards(source_text:, count:, locale: "pl")`
   - Cel: metoda wyspecjalizowana dla domeny fiszek.
   - Wewnątrz: buduje prompty i schema, deleguje do `generate_chat`.

3. `healthcheck`
   - Cel: techniczna walidacja konfiguracji i dostępności upstreamu (bez kosztownych requestów produkcyjnych).

### Publiczne pola/stałe

- `DEFAULT_MODEL`
- `DEFAULT_TIMEOUTS`
- `ALLOWED_MODELS`
- `ERROR_CODES` (słownik mapowań)

## 4. Prywatne metody i pola

### Prywatne metody

1. `build_messages(system_message:, user_message:)`
2. `build_response_format(schema_name:, schema_obj:)`
3. `build_payload(model:, messages:, response_format:, model_params:)`
4. `perform_request(payload)`
5. `parse_provider_response(raw_response)`
6. `validate_structured_output!(parsed_json, schema_obj)`
7. `map_provider_error(error_or_response)`
8. `sanitize_for_logs(payload_or_response)`
9. `with_retry_for_transient_errors { ... }`

### Prywatne pola

- `@api_key`, `@http_client`, `@base_url`, `@timeouts`, `@logger`, `@default_model`, `@default_params`

## 5. Obsługa błędów

### Scenariusze błędów (pełny przekrój)

1. Brak konfiguracji (`OPENROUTER_API_KEY` nieustawiony).
2. Błędy sieci (DNS, reset połączenia, timeout).
3. HTTP 400 (nieprawidłowy payload, błędny schema).
4. HTTP 401/403 (klucz nieważny, brak uprawnień).
5. HTTP 404/422 (nieobsługiwany model, niepoprawne parametry).
6. HTTP 429 (rate limit lub quota).
7. HTTP 5xx (awaria dostawcy).
8. Odpowiedź bez oczekiwanego pola treści.
9. Odpowiedź niebędąca poprawnym JSON mimo `response_format`.
10. Odpowiedź JSON niezgodna ze schematem.
11. Odpowiedź poprawna technicznie, ale odrzucona walidacją domenową.
12. Błąd zapisu do bazy po poprawnej odpowiedzi modelu.

### Strategia obsługi

- Kategoryzować błędy na: `configuration_error`, `network_error`, `provider_error`, `rate_limited`, `invalid_response_format`, `validation_error`, `persistence_error`.
- Retry stosować tylko dla błędów przejściowych (`network_error`, `provider_error` 5xx, część 429) z backoff.
- Każdy błąd mapować do `Result.failure(errors:, error_code:)`.
- Zapisywać incydenty do `GenerationErrorLog` z kontekstem biznesowym i maskowaniem danych wrażliwych.

## 6. Kwestie bezpieczeństwa

1. Trzymać API key wyłącznie po stronie backendu (credentials/env), nigdy w Stimulus/JS/HTML.
2. Filtrować sekretne nagłówki w logach (`Authorization`, tokeny).
3. Ograniczyć długość wejścia użytkownika i walidować encoding treści.
4. Wymusić whitelistę modeli (`ALLOWED_MODELS`) i limity parametrów.
5. Sanitizować dane zapisywane do logów błędów (PII minimization).
6. Używać HTTPS/TLS i walidacji certyfikatów po stronie klienta HTTP.
7. Chronić endpointy aplikacji przez autoryzację (`Current.user`) i limity per użytkownik.
8. Rozważyć throttling requestów generacji na poziomie aplikacji.

## 7. Plan wdrożenia krok po kroku

1. **Ustalenie kontraktów i konfiguracji**
   - Zdefiniować finalne `ERROR_CODES`, `ALLOWED_MODELS`, timeouty i profile parametrów.
   - Dodać konfigurację klucza OpenRouter do credentials/ENV oraz `filter_parameter_logging`.

2. **Refaktoryzacja `Ai::OpenrouterClient` z mock do realnego klienta**
   - Zaimplementować konstruktor z DI (`http_client`, `logger`).
   - Dodać metody: `generate_chat`, `generate_flashcards`, `healthcheck`.

3. **Budowa kontraktu wiadomości (`system`/`user`)**
   - Wydzielić `PromptBuilder` (lub prywatne metody klienta) dla spójnego tworzenia message.
   - Dodać limity i sanitizację `source_text`.

4. **Wdrożenie `response_format` z JSON Schema**
   - Zdefiniować schemat `flashcards_response`.
   - Budować payload w formacie:
   - `{ type: 'json_schema', json_schema: { name: [schema-name], strict: true, schema: [schema-obj] } }`.

5. **Parser i walidator odpowiedzi**
   - Parsować odpowiedź OpenRouter i walidować zgodność z JSON Schema.
   - Dodać walidacje domenowe (`front/back/source`, długości, liczność).

6. **Mapowanie błędów + retry policy**
   - Dodać mapowanie HTTP/network -> `error_code`.
   - Dodać retry z backoff tylko dla błędów przejściowych.

7. **Integracja z warstwą use case (`Generations::...`)**
   - Wywoływać klienta przez Service Object zwracający `Result`.
   - Zapis sukcesów do `Generation`/`Flashcard`, a porażek do `GenerationErrorLog`.

8. **Asynchroniczność i UX (Hotwire + Solid Queue)**
   - Dla dłuższych zadań przenieść wywołanie do joba.
   - Informować UI o statusie przez Turbo Streams (pending/success/error).

9. **Testy**
   - Unit: klient, parser, mapowanie błędów, walidacja schematu.
   - Service tests: `Generations::...` z sukcesem i błędami.
   - Request/integration: endpoint generacji + kontrakty odpowiedzi API.

10. **Obserwowalność i kontrola kosztu**
   - Logować metryki (`model`, `latency_ms`, `token_usage`, `error_code`).
   - Dodać alerty na wzrost 429/5xx i limity kosztów per środowisko.

11. **Rollout produkcyjny**
   - Włączyć feature flag dla realnych wywołań OpenRouter.
   - Start od małego procentu ruchu, monitorować błędy i koszt.
   - Po stabilizacji wyłączyć mock i ustawić klienta jako domyślnego.

12. **Utrzymanie**
   - Cyklicznie przeglądać jakość odpowiedzi modeli, koszty i parametry.
   - Aktualizować schematy `response_format` wraz ze zmianami domeny.
