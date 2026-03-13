# Architektura UI dla 10x-cards

## 1. Przegląd struktury UI

Architektura UI dla MVP opiera się na podejściu SSR + Hotwire, z minimalną warstwą JavaScript (Stimulus) i pełnym prowadzeniem stanu po stronie serwera. Interfejs jest podzielony na warstwę publiczną (logowanie/rejestracja) i warstwę chronioną (moje fiszki, generowanie AI, szczegóły talii, konto).

Kluczowe założenia struktury:
- Aplikacja jest mobile-first i responsywna.
- Użytkownik po zalogowaniu trafia do centrum pracy: /my-flashcards.
- Historia generacji i widok moje fiszki są tożsame na poziomie informacji o taliach.
- Propozycje AI są pokazywane na tej samej stronie co formularz generowania (bez przekierowania).
- Minimalna nawigacja MVP: Moje fiszki, Konto, Logo.
- Sesja nauki (US-008) jest poza zakresem MVP, ale architektura pozostawia miejsce na przyszły moduł.

Warstwy architektury UI:
- Warstwa nawigacyjna: stały top bar z globalnymi punktami wejścia.
- Warstwa ekranów: widoki dedykowane zadaniom użytkownika.
- Warstwa komponentów wspólnych: formularze auth, karty talii, lista fiszek, komunikaty systemowe, potwierdzenia akcji destrukcyjnych.
- Warstwa stanów: loading, empty, validation error, duplicate source, unauthorized, not found, AI failure.

Decyzje wpływające na UX i model interakcji:
- Generowanie AI jest synchroniczne w MVP z wyraźnym stanem oczekiwania.
- Propozycje są zarządzane jako rekordy fiszek ze statusem pending, dzięki czemu UI może operować na jednolitym modelu karty.
- Odrzucenie wszystkich czyści cały kontekst generacji i wraca do pustego formularza tworzenia.

## 2. Lista widoków

### Widok 1: Logowanie
- Nazwa widoku: Logowanie
- Ścieżka widoku: /login
- Główny cel: uwierzytelnienie istniejącego użytkownika.
- Kluczowe informacje do wyświetlenia:
  - Pola email i hasło.
  - Przycisk logowania.
  - Przycisk logowania przez Google SSO.
  - Link do rejestracji.
  - Komunikaty błędów logowania.
- Kluczowe komponenty widoku:
  - Formularz logowania.
  - Sekcja SSO.
  - Komunikaty inline dla błędów pól i błędu globalnego.
- UX, dostępność i względy bezpieczeństwa:
  - Jasne komunikaty o niepoprawnych danych bez ujawniania szczegółów konta.
  - Etykiety pól, focus states, obsługa klawiatury i czytników.
  - Ochrona przed brute force wspierana przez limity po stronie backendu.

Powiązanie z API:
- POST /api/v1/auth/sessions
- GET /api/v1/auth/google

### Widok 2: Rejestracja
- Nazwa widoku: Rejestracja
- Ścieżka widoku: /register
- Główny cel: utworzenie konta i automatyczne rozpoczęcie sesji.
- Kluczowe informacje do wyświetlenia:
  - Pola email, hasło, potwierdzenie hasła.
  - Przycisk rejestracji.
  - Przycisk rejestracji przez Google SSO.
  - Link do logowania.
  - Walidacja siły i zgodności hasła.
- Kluczowe komponenty widoku:
  - Formularz rejestracji.
  - Sekcja SSO.
  - Komunikaty walidacji inline.
- UX, dostępność i względy bezpieczeństwa:
  - Czytelne wskazanie wymagań hasła.
  - Komunikat o konflikcie adresu email.
  - Brak wycieku danych o innych kontach.

Powiązanie z API:
- POST /api/v1/auth/registrations
- GET /api/v1/auth/google

### Widok 3: Moje fiszki (hub)
- Nazwa widoku: Moje fiszki
- Ścieżka widoku: /generations
- Główny cel: centralny panel użytkownika do przeglądu talii i fiszek ręcznych oraz rozpoczęcia nowej generacji.
- Kluczowe informacje do wyświetlenia:
  - Zakładki: Talie i Ręczne.
  - W zakładce Talie: tytuł talii, data, model, licznik wygenerowanych i zaakceptowanych, pasek postępu.
  - W zakładce Ręczne: lista fiszek manualnych użytkownika.
  - CTA Generuj nową talię.
  - Empty state dla braku danych.
- Kluczowe komponenty widoku:
  - Przełącznik zakładek.
  - Lista kart talii.
  - Lista fiszek ręcznych.
  - Empty state z ilustracją i CTA.
  - Paginacja bookmarkowalna.
- UX, dostępność i względy bezpieczeństwa:
  - Wyraźne rozdzielenie treści taliowych i ręcznych.
  - Pełna obsługa dotyku i klawiatury na zakładkach.
  - Scopowanie danych do current user i nieujawnianie cudzych zasobów.

Powiązanie z API:
- GET /api/v1/generations
- GET /api/v1/flashcards?source=manual

### Widok 4: Generowanie nowej talii AI
- Nazwa widoku: Generowanie talii
- Ścieżka widoku: /generations/new
- Główny cel: wprowadzenie tekstu źródłowego, wygenerowanie propozycji i ich selekcja/edycja/zapis.
- Kluczowe informacje do wyświetlenia:
  - Pole tekstowe 1000-10000 znaków.
  - Stan ładowania i blokada formularza podczas generacji.
  - Lista propozycji z checkboxami, edycją inline i akcjami.
  - Komunikat o duplikacie z linkiem do istniejącej generacji.
  - Akcje Zapisz zaznaczone oraz Odrzuć wszystkie.
- Kluczowe komponenty widoku:
  - Formularz źródła tekstu.
  - Loader generacji.
  - Lista propozycji pending.
  - Edytor inline pojedynczej propozycji.
  - Pasek akcji zbiorczych.
- UX, dostępność i względy bezpieczeństwa:
  - Walidacja HTML5 jako wskazówka UX, serwer jako źródło prawdy.
  - Czytelne stany: loading, validation error, duplicate, AI failure.
  - Atomiczność zapisu zaznaczonych fiszek komunikowana użytkownikowi.

Powiązanie z API:
- POST /api/v1/generations
- POST /api/v1/flashcards (bulk)
- DELETE /api/v1/generations/:id

### Widok 5: Szczegóły talii
- Nazwa widoku: Szczegóły talii
- Ścieżka widoku: /generations/:id
- Główny cel: zarządzanie talią po generacji, w tym propozycjami pending i zapisanymi fiszkami.
- Kluczowe informacje do wyświetlenia:
  - Nagłówek talii: nazwa, data, model, metryki.
  - Sekcja A: propozycje do przejrzenia (pending).
  - Sekcja B: zapisane fiszki (approved/manual/ai_edited).
  - Akcje: edytuj, usuń, dodaj ręcznie, zapisz zaznaczone, odrzuć wszystkie.
  - Informacja, że tekst źródłowy nie podlega edycji.
- Kluczowe komponenty widoku:
  - Karta metadanych talii.
  - Lista pending z checkboxami.
  - Lista zapisanych fiszek.
  - Formularz dodania ręcznej fiszki do talii.
  - Potwierdzenie usuwania inline.
- UX, dostępność i względy bezpieczeństwa:
  - Uporządkowanie sekcji zmniejszające obciążenie poznawcze.
  - Potwierdzenia akcji destrukcyjnych bez natywnego okna blokującego.
  - 404 przy próbie dostępu do cudzej talii.

Powiązanie z API:
- GET /api/v1/generations/:id
- PATCH /api/v1/flashcards/:id
- DELETE /api/v1/flashcards/:id
- POST /api/v1/flashcards
- DELETE /api/v1/generations/:id

### Widok 6: Konto
- Nazwa widoku: Konto
- Ścieżka widoku: /account
- Główny cel: zarządzanie danymi użytkownika i realizacja prawa do usunięcia danych.
- Kluczowe informacje do wyświetlenia:
  - Aktualne dane profilu (co najmniej first_name, email readonly).
  - Formularz zmiany first_name.
  - Sekcja strefa niebezpieczna z usunięciem konta.
- Kluczowe komponenty widoku:
  - Formularz aktualizacji profilu.
  - Sekcja usunięcia konta z polem hasła.
  - Aktywacja przycisku usunięcia po spełnieniu warunku.
- UX, dostępność i względy bezpieczeństwa:
  - Wyraźna separacja akcji zwykłych i nieodwracalnych.
  - Jednoznaczne ostrzeżenia o skutkach usunięcia.
  - Wymóg potwierdzenia hasła dla kont lokalnych.

Powiązanie z API:
- GET /api/v1/auth/me
- DELETE /api/v1/account

### Widok 7: Widoki systemowe błędów i dostępu
- Nazwa widoku: Błędy systemowe
- Ścieżka widoku: /401, /404, /422, /500 (lub odpowiedniki w obrębie layoutu)
- Główny cel: bezpieczne prowadzenie użytkownika po błędach i odzyskiwanie ścieżki zadania.
- Kluczowe informacje do wyświetlenia:
  - Przyjazny komunikat o błędzie.
  - Możliwa akcja powrotu do Moje fiszki lub logowania.
- Kluczowe komponenty widoku:
  - Karta błędu.
  - CTA odzyskania nawigacji.
- UX, dostępność i względy bezpieczeństwa:
  - Brak ujawniania szczegółów technicznych.
  - Jasny język i jedna główna akcja naprawcza.

Powiązanie z API:
- Wszystkie endpointy w scenariuszach błędów autoryzacji, walidacji, not found i failure.

## 3. Mapa podróży użytkownika

### Główny przypadek użycia MVP (US-003 + US-004 + US-005)
1. Użytkownik loguje się na /login.
2. Po sukcesie trafia na /my-flashcards.
3. Wybiera CTA Generuj nową talię i przechodzi do /generations/new.
4. Wkleja tekst źródłowy i uruchamia generowanie.
5. Widzi loader i po chwili propozycje pending w tym samym widoku.
6. Przegląda propozycje, zaznacza wartościowe, opcjonalnie edytuje inline.
7. Zapisuje zaznaczone fiszki.
8. Trafia do /generations/:id lub pozostaje w kontekście generacji z potwierdzeniem zapisu.
9. W szczegółach talii może dalej edytować, usuwać i dodawać fiszki ręczne.
10. Wraca do /generations, gdzie widzi postęp i historię talii.

### Podróż dla ręcznych fiszek (US-007)
1. Użytkownik przechodzi do /generations.
2. Otwiera zakładkę Ręczne.
3. Tworzy nową fiszkę manualną (w sekcji tworzenia dla zakładki lub w widoku talii jako ai_edited).
4. Edytuje lub usuwa istniejące fiszki.

### Podróż konta i prywatności (US-001, US-002, US-009)
1. Użytkownik rejestruje konto przez /register lub loguje się przez /login.
2. Korzysta z zasobów widocznych wyłącznie w zakresie własnych danych.
3. W /account aktualizuje first_name lub uruchamia usunięcie konta.
4. Po usunięciu konta następuje wylogowanie i powrót do warstwy publicznej.

### Podróż błędowa i odzyskiwanie
1. Duplikat źródła: użytkownik otrzymuje inline informację z linkiem do istniejącej generacji.
2. Błąd AI: użytkownik otrzymuje toast i pozostaje w formularzu z zachowanym kontekstem wejścia.
3. Nieautoryzowany dostęp: użytkownik jest kierowany do logowania.
4. Dostęp do cudzego zasobu: użytkownik dostaje 404 bez ujawniania istnienia danych.

### Mapowanie historyjek użytkownika (US) do widoków
- US-001 Rejestracja konta: /register
- US-002 Logowanie: /login
- US-003 Generowanie AI: /generations/new
- US-004 Przegląd i zatwierdzanie: /generations/new oraz /generations/:id
- US-005 Edycja fiszek: /generations/:id oraz zakładka Ręczne w /my-flashcards
- US-006 Usuwanie fiszek: /generations/:id oraz zakładka Ręczne w /my-flashcards
- US-007 Ręczne tworzenie: /my-flashcards (Ręczne) oraz /generations/:id (dodaj ręcznie do talii)
- US-008 Sesja nauki: poza MVP, punkt rozszerzenia w nawigacji przyszłej
- US-009 Bezpieczny dostęp i autoryzacja: dotyczy wszystkich widoków chronionych

## 4. Układ i struktura nawigacji

Nawigacja globalna MVP:
- Logo (powrót do /my-flashcards dla zalogowanego, do /login dla niezalogowanego).
- Moje fiszki.
- Konto.

Nawigacja kontekstowa:
- W /my-flashcards: zakładki Talie i Ręczne.
- W /generations/new: akcje kontekstowe dla propozycji (zapis, odrzucenie).
- W /generations/:id: sekcje Propozycje i Zapisane fiszki, z lokalnymi akcjami edycji/usuwania.

Reguły routingu i uprawnień:
- Widoki publiczne: /login, /register.
- Widoki chronione: /generations, /generations/new, /generations/:id, /account.
- Próba wejścia bez sesji: przekierowanie do logowania.
- Próba wejścia do zasobu poza własnym zakresem: 404.

Wzorzec nawigacji po sukcesie akcji:
- Logowanie/rejestracja: redirect do /my-flashcards.
- Utworzenie generacji: pozostanie na /generations/new z wynikami.
- Odrzucenie wszystkich: reset do pustego /generations/new.
- Usunięcie konta: wylogowanie i przejście do /login.

## 5. Kluczowe komponenty

### Komponenty wielokrotnego użytku
- Pasek nawigacyjny aplikacji:
  - Globalna orientacja, szybki dostęp do głównych sekcji.
- Komunikaty systemowe (toast/inline):
  - Informacje o sukcesie, błędzie, walidacji i stanie API.
- Karta talii:
  - Tytuł, data, model, metryki, postęp akceptacji.
- Karta fiszki:
  - Front, back, status, akcje edycji/usunięcia/zatwierdzenia.
- Formularz fiszki:
  - Wspólny dla tworzenia i edycji z walidacją długości pól.
- Panel akcji zbiorczych:
  - Zapisz zaznaczone i Odrzuć wszystkie dla propozycji pending.
- Komponent potwierdzenia akcji destrukcyjnej:
  - Inline potwierdzenie dla usuwania fiszki i konta.
- Komponent pustego stanu:
  - Ilustracja, krótkie wyjaśnienie i pojedyncze CTA.
- Komponent paginacji:
  - Spójny dla list talii i fiszek.

### Mapowanie wymagań produktu na elementy UI
- Automatyczne generowanie fiszek:
  - Formularz źródła, loader, lista propozycji, edycja inline, akceptacja zbiorcza.
- Ręczne zarządzanie fiszkami:
  - Zakładka Ręczne, formularz tworzenia, edycja i usuwanie.
- Uwierzytelnianie i konta:
  - Widoki login/register, konto, usunięcie konta.
- Integracja z powtórkami:
  - Oznaczenie jako przyszły moduł i miejsce rozszerzenia nawigacji.
- Przechowywanie i skalowalność:
  - Widoki listowe z paginacją i prostymi filtrami.
- Statystyki generowania:
  - Metryki na kartach talii i w szczegółach talii.
- Wymogi prawne RODO:
  - Strefa niebezpieczna i jednoznaczna ścieżka usunięcia konta.

### Punkty bólu użytkownika i rozwiązania UI
- Długi czas oczekiwania na AI:
  - Wyraźny loader, blokada duplikacji submitu, informacja o postępie.
- Niepewność jakości propozycji:
  - Edycja inline przed zatwierdzeniem i zapis tylko zaznaczonych.
- Ryzyko utraty danych przy akcjach destrukcyjnych:
  - Potwierdzenia inline i jasne komunikaty skutków.
- Trudność odnalezienia poprzednich wyników:
  - Hub /my-flashcards z historią talii i postępem.
- Frustracja przy duplikacji źródła:
  - Bezpośredni link do istniejącej generacji zamiast ślepego błędu.

### Zgodność architektury UI z planem API
- Każdy widok ma bezpośrednie mapowanie do wymaganych endpointów auth, generations, flashcards i account.
- Operacje listowania, szczegółów, tworzenia, aktualizacji i usuwania są odzwierciedlone w dedykowanych elementach UI.
- Scenariusze błędowe z API mają odpowiadające stany interfejsu.
- Zasada user scoping i 404 dla cross-tenant jest odzwierciedlona w regułach nawigacji i dostępu.
