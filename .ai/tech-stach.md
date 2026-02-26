Frontend

Widoki: HTML renderowany po stronie serwera za pomocą szablonów ERB.

Interaktywność: Hotwire. Wykorzystanie Turbo (Drive, Frames, Streams) do zapewnienia płynności działania znanej z aplikacji SPA (np. dynamiczne odświeżanie kolejki fiszek bez przeładowania strony) oraz Stimulus.js do prostej interaktywności w przeglądarce.

Stylowanie: Tailwind CSS (v4) do sprawnego budowania i stylizowania interfejsu użytkownika.

Backend i baza danych

Framework: Ruby on Rails (wersja 8+) jako główne, scentralizowane środowisko dla całej logiki biznesowej i zarządzania stanem aplikacji.

Baza danych: PostgreSQL jako główna, relacyjna baza danych.

ORM: Active Record do modelowania danych i komunikacji z bazą PostgreSQL.

Autentykacja: System autentykacji oparty na natywnych rozwiązaniach Rails (lub klasycznym Devise) w połączeniu z omniauth-google-oauth2 do wdrożenia logowania przez Google SSO.

Komunikacja z modelami AI

Dostawca (Gateway): OpenRouter.ai, pełniący rolę bramki API, co daje elastyczność w doborze modeli LLM (np. szybkich i tanich modeli do MVP) oraz pozwala na centralne limitowanie budżetu.

Integracja w kodzie: Serwerowa komunikacja HTTP. Logika generowania promptów i parsowania odpowiedzi zostanie zamknięta w dedykowanych klasach Rails (Service Objects), chroniąc klucze API przed dostępem ze strony klienta.

CI/CD i hosting (DigitalOcean)

Serwer docelowy: Wirtualna maszyna (Droplet) wykupiona w usłudze DigitalOcean.

Automatyzacja CI/CD: GitHub Actions odpowiedzialne za uruchamianie testów, lintowanie kodu oraz budowanie obrazów po wrzuceniu zmian do repozytorium.

Wdrażanie (Deployment): Docker wraz z narzędziem Kamal (natywnym dla nowych wersji Rails) do automatyzacji procesu wdrażania (zero-downtime deployment), eliminując potrzebę ręcznej konfiguracji złożonych pipeline'ów.
