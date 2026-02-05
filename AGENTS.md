# Timevoice

Rails 8 + Inertia.js + Svelte 5 + Tailwind 4 time tracking & invoicing app.

## Commands
- **Dev server:** `bin/dev`
- **Rails tests:** `bin/rails test` | Single: `bin/rails test test/models/user_test.rb` or `bin/rails test test/models/user_test.rb:42`
- **System tests:** `bin/rails test:system`
- **Lint Ruby:** `bin/rubocop` | Fix: `bin/rubocop -a`
- **TypeScript/Svelte check:** `npm run check`
- **Format frontend:** `npm run format`

## Architecture
- **Backend:** Rails (Propshaft, Solid Queue/Cache/Cable, Pundit authorization, Doorkeeper OAuth)
- **Frontend:** Svelte 5 in `app/frontend/`, served via Inertia.js + Vite
- **Database:** SQLite (dev/test), PostgreSQL (prod)
- **Services:** `app/services/` for business logic, `app/policies/` for Pundit policies

## Code Style
- Ruby: rubocop-rails-omakase (no comments unless complex)
- Frontend: Prettier for Svelte/ERB, TypeScript strict mode
- Use hashids for public-facing IDs, never expose raw database IDs
