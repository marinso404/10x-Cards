# 10x Cards

AI-powered flashcard generation and spaced repetition learning platform. Paste any text and let AI create study flashcards for you — review, edit, and learn with an integrated spaced repetition algorithm.

## Table of Contents

- [Project Description](#project-description)
- [Tech Stack](#tech-stack)
- [Getting Started Locally](#getting-started-locally)
- [Available Scripts](#available-scripts)
- [Project Scope](#project-scope)
- [Project Status](#project-status)
- [License](#license)

## Project Description

10x Cards helps users rapidly create and manage educational flashcard sets. Instead of spending hours manually writing questions and answers, users can paste a block of text (e.g. a textbook excerpt) and the application will use a Large Language Model via the OpenRouter.ai API to propose a set of flashcards. Users can then accept, edit, or reject each suggestion before saving.

Key features:

- **AI Flashcard Generation** — paste 1 000–10 000 characters of source text and receive AI-generated flashcard proposals.
- **Review & Approve** — accept, edit, or reject each generated card before saving.
- **Manual Creation** — create flashcards by hand with a simple front/back form.
- **Full CRUD** — edit and delete any flashcard in your collection.
- **Spaced Repetition** — study sessions powered by an open-source spaced repetition algorithm.
- **User Accounts** — registration, login, and per-user data isolation.
- **Generation Statistics** — track how many AI-generated cards were accepted vs. rejected.

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Ruby on Rails 8 (Omakase) |
| **Database** | PostgreSQL |
| **Frontend** | Hotwire (Turbo Drive / Frames / Streams, Stimulus.js) |
| **Styling** | Tailwind CSS v4 |
| **AI Integration** | OpenRouter.ai (server-side Service Objects) |
| **Background Jobs** | Solid Queue |
| **Caching** | Solid Cache |
| **WebSockets** | Solid Cable |
| **JS Bundling** | esbuild |
| **Asset Pipeline** | Propshaft |
| **Deployment** | Docker + Kamal on DigitalOcean |
| **CI/CD** | GitHub Actions |
| **Testing** | Minitest, Capybara, Selenium |

## Getting Started Locally

### Prerequisites

- **Ruby** 3.3+
- **PostgreSQL** 14+
- **Node.js** 20+ and **Bun** (or Yarn)
- **Foreman** gem (installed automatically by `bin/dev`)

### Installation

```bash
# Clone the repository
git clone https://github.com/<your-org>/ten-x-cards.git
cd ten-x-cards

# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
bun install        # or: yarn install

# Create and migrate the database
bin/rails db:prepare

# (Optional) set up credentials — e.g. OpenRouter API key
bin/rails credentials:edit
```

### Running the Development Server

```bash
bin/dev
```

This starts three processes via Foreman (see `Procfile.dev`):

| Process | Command |
|---|---|
| **web** | `bin/rails server` (Puma on port 3000) |
| **js** | `yarn build --watch` (esbuild) |
| **css** | `bun run build:css --watch` (Tailwind CSS) |

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Quick Setup (All-in-One)

```bash
bin/setup
```

This script installs dependencies, prepares the database, clears logs/tmp, and starts the dev server.

## Available Scripts

### Rails / Ruby

| Command | Description |
|---|---|
| `bin/dev` | Start all development processes (web, JS, CSS) |
| `bin/setup` | Bootstrap the application (install deps, prepare DB, start server) |
| `bin/rails server` | Start the Rails server only |
| `bin/rails db:prepare` | Create / migrate the database |
| `bin/rails db:reset` | Drop, recreate, and seed the database |
| `bin/rails console` | Open the Rails console |
| `bin/rubocop` | Run RuboCop linter (Omakase style) |
| `bin/brakeman` | Run Brakeman security scanner |
| `bin/bundler-audit` | Audit gems for known vulnerabilities |
| `bin/ci` | Run the full CI suite |
| `bin/kamal` | Manage Kamal deployments |

### JavaScript / CSS

| Command | Description |
|---|---|
| `bun run build` | Bundle JavaScript with esbuild |
| `bun run build:css` | Compile Tailwind CSS |

## Project Scope

### In Scope (MVP)

- AI-powered flashcard generation from pasted text
- Manual flashcard creation, editing, and deletion
- User registration and authentication
- Per-user data isolation and authorization
- Spaced repetition study sessions (using an open-source algorithm)
- Flashcard generation statistics (accepted vs. rejected)
- GDPR-compliant data storage with right to deletion

### Out of Scope

- Custom spaced repetition algorithm
- Gamification features
- Native mobile applications
- Document import (PDF, DOCX, etc.)
- Public API
- Flashcard sharing between users
- Advanced notification system
- Full-text search across flashcards

## Project Status

The project is in **early development** (MVP phase). Core scaffolding and infrastructure are in place; feature implementation is underway.

## License

This project is private and not currently published under an open-source license.
