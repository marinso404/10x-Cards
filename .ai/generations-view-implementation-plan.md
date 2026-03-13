# Plan implementacji widoku Generowanie talii

## 1. Przegląd
Widok Generowanie talii pod sciezka /generations/new sluzy do pelnego przeplywu: wprowadzenie tekstu zrodlowego, wyslanie go do AI, przeglad propozycji fiszek, ich selekcja i ewentualna edycja inline, a nastepnie atomowy zapis zaznaczonych fiszek. Widok musi obslugiwac stany: idle, walidacja lokalna, ladowanie, sukces, duplikat, blad AI oraz zapis/odrzucenie propozycji.

Cel biznesowy widoku wspiera US-003 i US-004 bezposrednio oraz przygotowuje dane pod US-005 i US-006 (edycja i redukcja niechcianych kart) jeszcze na etapie akceptacji propozycji AI.

## 2. Routing widoku
- Strona SSR: GET /generations/new
- Widok HTML: app/views/generations/new.html.erb
- Kontroler webowy: GenerationsController#new (warstwa HTML, nie API)
- Integracje API z poziomu frontendu (fetch):
  - POST /api/v1/generations
  - POST /api/v1/flashcards (bulk)
  - DELETE /api/v1/generations/:id

Uwaga implementacyjna: w aktualnym kodzie API istnieje tylko POST /api/v1/generations. Plan zaklada rownolegla implementacje brakujacych endpointow albo fallback UI (lokalne odrzucenie propozycji bez DELETE) do czasu ich dodania.

## 3. Struktura komponentow
Widok SSR + kontrolery Stimulus (bez SPA routera):

1. GenerationsNewPage
2. SourceTextForm
3. GenerationLoader
4. ProposalsList
5. ProposalRow
6. InlineProposalEditor
7. BulkActionsBar
8. StatusBanner

Drzewo komponentow (wysokopoziomowo):

1. GenerationsNewPage
2. SourceTextForm
3. StatusBanner
4. GenerationLoader
5. ProposalsList
6. ProposalRow (xN)
7. InlineProposalEditor (w ProposalRow)
8. BulkActionsBar

## 4. Szczegoly komponentow
### GenerationsNewPage
- Opis komponentu: kontener widoku, laczy sekcje formularza, listy i akcji zbiorczych; utrzymuje glowny stan ekranu.
- Glowne elementy: section, h1, kontener na komunikaty, kontener listy propozycji.
- Obslugiwane interakcje: inicjalizacja, reset stanu po zapisaniu, przejscie do historii generacji po duplikacie.
- Obslugiwana walidacja: brak bezposredniej walidacji domenowej, jedynie propagacja stanu globalnego.
- Typy: GenerationViewState, GenerationUIFlags.
- Propsy: brak (korzen widoku).

### SourceTextForm
- Opis komponentu: formularz przyjmujacy source_text i uruchamiajacy generowanie.
- Glowne elementy: form, textarea, licznik znakow, przycisk Generuj propozycje.
- Obslugiwane interakcje:
  - input: aktualizacja licznika i stanu walidacji
  - submit: POST /api/v1/generations
  - disable/enable: blokada formularza podczas requestu
- Obslugiwana walidacja:
  - HTML5: required, minlength=1000, maxlength=10000
  - Runtime UX: trim i komunikat o aktualnej dlugosci
  - API source of truth: 400 invalid_request dla pustego lub dlugosci poza zakresem
- Typy: CreateGenerationRequestDto, CreateGenerationResponseDto, ApiErrorDto.
- Propsy:
  - initialSourceText: string
  - isSubmitting: boolean
  - onSubmit(sourceText: string): Promise<void>

### GenerationLoader
- Opis komponentu: wizualizacja stanu generacji AI i blokady edycji.
- Glowne elementy: region statusu (aria-live), spinner/szkielet, tekst postepu.
- Obslugiwane interakcje: brak aktywnych akcji uzytkownika.
- Obslugiwana walidacja: brak.
- Typy: GenerationProgressViewModel.
- Propsy:
  - visible: boolean
  - label: string

### StatusBanner
- Opis komponentu: wspolny komponent komunikatow (blad, ostrzezenie, sukces, duplikat).
- Glowne elementy: alert, opis, opcjonalny link akcji.
- Obslugiwane interakcje: klikniecie linku do istniejacej generacji przy duplikacie.
- Obslugiwana walidacja: mapowanie kodow API na warianty bannera.
- Typy: UiMessageViewModel, DuplicateInfoViewModel.
- Propsy:
  - message: UiMessageViewModel | null
  - onDismiss(): void

### ProposalsList
- Opis komponentu: lista wygenerowanych propozycji pending po sukcesie POST /api/v1/generations.
- Glowne elementy: ul/ol, naglowek listy, liczniki zaznaczonych i wszystkich.
- Obslugiwane interakcje: zaznacz wszystko, odznacz wszystko, przekazywanie zdarzen z wierszy.
- Obslugiwana walidacja:
  - przed zapisem wymagane min. 1 zaznaczona fiszka
  - front 1..200 i back 1..500 dla pozycji edytowanych
- Typy: FlashcardProposalViewModel[].
- Propsy:
  - proposals: FlashcardProposalViewModel[]
  - disabled: boolean
  - onProposalChange(updated: FlashcardProposalViewModel): void

### ProposalRow
- Opis komponentu: pojedyncza propozycja z checkboxem, podgladem front/back i akcjami edycja/usun z listy.
- Glowne elementy: checkbox, tekst front/back, przyciski Edytuj i Odrzuc.
- Obslugiwane interakcje:
  - toggle zaznaczenia
  - wejscie/wyjscie z trybu edycji
  - odrzucenie pojedynczej propozycji (usuniecie lokalne)
- Obslugiwana walidacja: wskazanie bledow inline dla front/back po edycji.
- Typy: FlashcardProposalViewModel.
- Propsy:
  - proposal: FlashcardProposalViewModel
  - disabled: boolean
  - onToggle(id: string): void
  - onEdit(id: string): void
  - onReject(id: string): void

### InlineProposalEditor
- Opis komponentu: edycja tresci front/back dla konkretnej propozycji.
- Glowne elementy: input/textarea dla front i back, akcje Zapisz zmiany/Anuluj.
- Obslugiwane interakcje: input, submit, cancel.
- Obslugiwana walidacja:
  - front: wymagane, 1..200 po trim
  - back: wymagane, 1..500 po trim
  - blokada zapisu przy invalid
- Typy: FlashcardDraftViewModel, FieldErrorMap.
- Propsy:
  - draft: FlashcardDraftViewModel
  - onSave(draft: FlashcardDraftViewModel): void
  - onCancel(): void

### BulkActionsBar
- Opis komponentu: pasek akcji dla zapisania zaznaczonych i odrzucenia wszystkich.
- Glowne elementy: licznik selected/total, przycisk Zapisz zaznaczone, przycisk Odrzuc wszystkie.
- Obslugiwane interakcje:
  - click Zapisz zaznaczone -> POST /api/v1/flashcards (bulk)
  - click Odrzuc wszystkie -> DELETE /api/v1/generations/:id (lub fallback lokalny)
- Obslugiwana walidacja:
  - zapis wymaga selectedCount > 0
  - blokada podczas requestu
- Typy: SaveSelectionRequestDto, SaveSelectionResponseDto.
- Propsy:
  - selectedCount: number
  - totalCount: number
  - isSaving: boolean
  - isDiscarding: boolean
  - onSaveSelected(): Promise<void>
  - onDiscardAll(): Promise<void>

## 5. Typy
Typy DTO (kontrakt API):

1. CreateGenerationRequestDto
  - source_text: string

2. CreateGenerationResponseDto
  - generation_id: number
  - flashcards_proposals: FlashcardProposalDto[]
  - generated_count: number

3. FlashcardProposalDto
  - id: string
  - front: string
  - back: string
  - source: string

4. BulkCreateFlashcardsRequestDto
  - flashcards: BulkCreateFlashcardItemDto[]

5. BulkCreateFlashcardItemDto
  - front: string
  - back: string
  - source: "manual" | "ai_generated" | "ai_edited"
  - generation_id?: number

6. BulkCreateFlashcardsResponseDto
  - data: {
    created_flashcards: Array<{ id: number; source: string; generation_id: number | null }>
    count: number
  }

7. ApiErrorDto
  - error: {
    code: string
    message: string
    details?: Record<string, string[]>
  }

Typy ViewModel (UI):

1. GenerationViewState
  - sourceText: string
  - generationId: number | null
  - proposals: FlashcardProposalViewModel[]
  - message: UiMessageViewModel | null
  - flags: GenerationUIFlags

2. GenerationUIFlags
  - isGenerating: boolean
  - isSaving: boolean
  - isDiscarding: boolean
  - isDirty: boolean

3. FlashcardProposalViewModel
  - localId: string
  - remoteId: string
  - front: string
  - back: string
  - sourceKind: "ai_generated" | "ai_edited"
  - selected: boolean
  - editing: boolean
  - errors: FieldErrorMap

4. FlashcardDraftViewModel
  - front: string
  - back: string

5. FieldErrorMap
  - front?: string
  - back?: string

6. UiMessageViewModel
  - kind: "success" | "error" | "warning" | "info"
  - code: string
  - title: string
  - body: string
  - actionLabel?: string
  - actionHref?: string

7. DuplicateInfoViewModel
  - duplicate: boolean
  - existingGenerationId?: number

Mapowanie source propozycji AI:
- Backend zwraca source: "ai-full" w propozycjach, ale model Flashcard wymaga "ai_generated" lub "ai_edited" przy zapisie.
- Regula UI:
  - nieedytowana propozycja -> "ai_generated"
  - edytowana propozycja -> "ai_edited"

## 6. Zarzadzanie stanem
Rekomendowany model: SSR + jeden kontroler Stimulus, np. generations_new_controller.js, jako lokalny store stanu widoku.

Zakres stanu:
1. sourceText oraz sourceLength
2. proposals[] z polami selected/editing/errors
3. generationId
4. ui flags: isGenerating, isSaving, isDiscarding
5. globalny komunikat (message banner)

Czy potrzebny custom hook:
- W tym stacku nie ma React hookow; odpowiednikiem jest wydzielenie modulow pomocniczych:
  - useProposalValidation (czysta funkcja walidujaca front/back)
  - useApiErrorMapper (mapowanie ApiErrorDto -> UiMessageViewModel)
  - useProposalSourceMapper (ai-full -> ai_generated/ai_edited)

Sposob uzycia:
- Stimulus trzyma stan i wywoluje helpery podczas input/submit.
- Aktualizacja DOM przez targety Stimulus i warunkowe klasy Tailwind.

## 7. Integracja API
### POST /api/v1/generations
- Request: CreateGenerationRequestDto
- Success (realnie): HTTP 201 Created
- Success body: CreateGenerationResponseDto
- Obsluga frontendowa:
  1. Ustaw isGenerating=true i zablokuj formularz.
  2. Wyczysc poprzednie propozycje i komunikaty.
  3. Po sukcesie zapisz generationId i proposals.
  4. Wylacz loader, odblokuj formularz.

Mapowanie bledow:
- 400 invalid_request: pokaz blad walidacji formularza
- 422 invalid_request (duplikat): pokaz StatusBanner z linkiem do historii generacji
- 500 generation_failed/internal_error: pokaz blad globalny i CTA Sprobuj ponownie

### POST /api/v1/flashcards (bulk)
- Request: BulkCreateFlashcardsRequestDto
- Action frontendowa: Zapisz zaznaczone
- Warunki:
  - selectedCount > 0
  - kazdy element po trim spelnia front 1..200, back 1..500
  - generation_id dolaczane dla kart AI

Po sukcesie:
- Pokaz komunikat sukcesu z liczba zapisanych fiszek.
- Wyczysc proposals lub pozostaw tylko niezaznaczone (decyzja UX: rekomendowane wyczyszczenie calosci po sukcesie atomowym).

### DELETE /api/v1/generations/:id
- Action frontendowa: Odrzuc wszystkie
- Gdy endpoint dostepny:
  - wyslij DELETE dla aktualnego generationId
  - po sukcesie wyczysc liste i komunikat
- Fallback gdy endpoint niedostepny:
  - lokalnie wyczysc proposals
  - pokaz info, ze sesja propozycji zostala odrzucona lokalnie

## 8. Interakcje uzytkownika
1. Uzytkownik wkleja tekst 1000-10000 znakow.
2. Klikniecie Generuj propozycje uruchamia loader i blokuje formularz.
3. Po sukcesie uzytkownik widzi liste propozycji z checkboxami.
4. Uzytkownik moze:
  - zaznaczac/odznaczac propozycje
  - edytowac front/back inline
  - odrzucic pojedyncza propozycje
5. Klikniecie Zapisz zaznaczone uruchamia atomowy zapis bulk.
6. Klikniecie Odrzuc wszystkie usuwa caly zestaw propozycji (API lub fallback lokalny).
7. W scenariuszu duplikatu UI pokazuje komunikat i link do istniejacej generacji.

## 9. Warunki i walidacja
Walidacje formularza zrodla:
1. source_text wymagane
2. source_text po trim: minimum 1000, maksimum 10000
3. podczas isGenerating formularz i przycisk disabled

Walidacje propozycji przed bulk save:
1. minimum jedna zaznaczona propozycja
2. front po trim: 1..200
3. back po trim: 1..500
4. source wyliczone jako ai_generated lub ai_edited
5. generation_id obecne dla kart AI

Walidacje stanu akcji:
1. zablokowanie rownoleglego submitu (isGenerating/isSaving/isDiscarding)
2. idempotentne klikniecia przyciskow (disabled + guard w kodzie)

Walidacje dostepnosci:
1. aria-live dla komunikatow i loadera
2. aria-invalid + powiazanie bledow pol przez aria-describedby
3. widoczny focus ring dla elementow interaktywnych

## 10. Obsluga bledow
Scenariusze i reakcje UI:

1. 400 invalid_request (POST /generations)
- Komunikat przy polu source_text i banner z opisem.

2. 422 duplikat generacji
- Banner warning z trescia o duplikacie i linkiem do istnieacej generacji.
- Nie nadpisywac aktualnych propozycji, jesli juz sa na ekranie.

3. 500 generation_failed / internal_error
- Banner error + przycisk ponowienia.
- Zachowac source_text, aby nie tracic danych uzytkownika.

4. Blad bulk save (400/401/404/422/413/500)
- Pokazac blad globalny.
- Zachowac selection i edycje, aby user mogl poprawic i ponowic zapis.

5. Timeout / network error
- Banner error z komunikatem o problemie sieciowym.
- Umozliwic retry bez resetu formularza.

6. Brak endpointu DELETE /generations/:id
- Fallback lokalny + komunikat info.
- Dodac telemetry/log klienta dla monitoringu brakujacej funkcji.

## 11. Kroki implementacji
1. Dodac routing i warstwe SSR widoku:
  - GET /generations/new
  - app/controllers/generations_controller.rb (akcja new)
  - app/views/generations/new.html.erb

2. Zbudowac layout widoku i sekcje komponentowe w ERB:
  - SourceTextForm
  - StatusBanner
  - Loader
  - ProposalsList
  - BulkActionsBar

3. Dodac kontroler Stimulus generations_new_controller.js:
  - inicjalny stan
  - obsluga input/submit
  - render listy i flag UI

4. Dodac helpery domenowe JS:
  - walidacja source_text i propozycji
  - mapowanie source ai-full -> ai_generated/ai_edited
  - mapowanie ApiErrorDto -> UiMessageViewModel

5. Zaimplementowac integracje POST /api/v1/generations:
  - request JSON z source_text
  - obsluga 201/400/422/500
  - aktualizacja generationId i proposals

6. Zaimplementowac interakcje listy:
  - select/unselect
  - edycja inline
  - odrzucanie pojedynczych pozycji
  - liczniki selected/total

7. Zaimplementowac Zapisz zaznaczone (POST /api/v1/flashcards bulk):
  - budowa payloadu z generation_id
  - atomowy flow zapisu
  - obsluga sukcesu i bledow

8. Zaimplementowac Odrzuc wszystkie:
  - wersja docelowa: DELETE /api/v1/generations/:id
  - fallback lokalny do czasu gotowosci endpointu

9. Dopracowac UX i a11y:
  - stany disabled, aria-live, aria-invalid
  - czytelne komunikaty dla loading/validation/duplicate/failure
  - responsywnosc mobile/desktop

10. Testy i walidacja koncowa:
  - testy systemowe dla flow US-003 i US-004
  - testy jednostkowe helperow walidacji/mappingu
  - test scenariuszy bledow API i timeout

11. Techniczny follow-up backendowy:
  - upewnic sie, ze POST /api/v1/flashcards (bulk) i DELETE /api/v1/generations/:id sa dostepne
  - uzgodnic finalny kontrakt duplikatu (czy zwracac existing_generation_id)
  - doprecyzowac source zwracane przez AI (obecnie ai-full) wzgledem modelu Flashcard
