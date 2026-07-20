# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rails 8 app for a mining company's truck loading queue management system (registration → yard
check-in → order issuance → queue → loading → finished, with SMS/WhatsApp notifications and a
public real-time screen). Greenfield, built incrementally in 10 phases.

**Read `docs/plan.md` first** — it is the full architecture/design reference (data model, state
machine, notifications design, authorization design, testing strategy, file layout, all 10 build
phases). **Read `docs/progress.md` second** — it is the execution log, updated at the end of every
completed phase, showing what's actually implemented vs. still planned, and documents deviations
from the plan discovered along the way (e.g. Avo resolved to v4.x, not the 3.x the plan assumed).

All 10 phases are done (skeleton; Driver/Truck registration; Visit/check-in; dispatch; queue;
public Turbo Streams screen; notifications; Avo admin; test/styling pass; production hardening) —
this is a complete v1, not a work-in-progress. See `docs/progress.md` for the full execution log,
including deviations from `docs/plan.md` discovered along the way (e.g. Avo resolved to v4.x, not
the 3.x the plan assumed; the `Queue::` module was renamed to `QueueScreen::` because it collides
with Ruby's stdlib `Queue` class; Avo's Pundit integration, `avo-authorization`, turned out to be a
paid plugin, so `/admin` uses a single admin-only `authenticate_with` gate instead). Remaining work
is explicitly out of v1 scope — see `docs/plan.md`'s "Future improvements" section (visit
cancellation, additional notification events, multi-site support, `en` locale) and
`docs/progress.md`'s "Project status" section (what a real production deploy would still need:
real Postgres/Redis host, `config.hosts`, a provisioned `RAILS_MASTER_KEY`, real Twilio
credentials).

When completing a phase, update `docs/progress.md` (status table + a new phase section) the same
way Phase 1 was documented, so the next session can resume without rebuilding context.

## Commands

This app has no local Ruby installed — everything runs through Docker Compose (`web`, `worker`,
`db`, `redis` services; `Dockerfile.dev` includes Chromium for Cuprite system specs).

```bash
# bring up the full stack
docker compose up -d

# prepare / seed the dev database (seeds create the 4 roles + 1 admin user)
docker compose run --rm web bin/rails db:prepare
docker compose run --rm web bin/rails db:seed

# run the test suite
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec

# run a single spec file / example
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/models/user_spec.rb
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/models/user_spec.rb:12

# lint (rubocop-rails-omakase) and security scan
docker compose run --rm web bin/rubocop
docker compose run --rm web bin/brakeman

# rails console / generators
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails generate model Foo
```

App runs at http://localhost:3000; log in with `ADMIN_EMAIL`/`ADMIN_PASSWORD` from `.env`
(defaults to `admin@example.com` / `changeme123` in dev, set in `db/seeds.rb`).

**Windows/Git Bash note**: Docker bind mounts via `-v "$(pwd):/app"` silently create an anonymous
volume instead of mounting the host directory. If running raw `docker run` commands (not
`docker compose`, which is already set up correctly), use the Windows-style path
(`-v "D:/Sites:/app"`) with `MSYS_NO_PATHCONV=1`.

## Production

No deploy tooling (Kamal, CI/CD) exists yet — this is manual `docker build`/`docker run`, per the
top-of-file comment in `Dockerfile`. The image is shared between the web and worker roles (same
pattern as `docker-compose.yml`'s dev services): default `CMD` runs the Rails server; override it
to run Sidekiq instead.

```bash
docker build -t app .

# web — runs db:prepare (create+migrate+seed) automatically on boot, per bin/docker-entrypoint
docker run -d -p 80:3000 \
  -e RAILS_MASTER_KEY=<config/master.key> \
  -e DATABASE_URL=postgres://app:<password>@<db-host>:5432/app_production \
  -e REDIS_URL=redis://<redis-host>:6379/0 \
  --name app app

# worker — same image, CMD overridden; does NOT run db:prepare (only the exact
# `./bin/rails server` command triggers it — see bin/docker-entrypoint)
docker run -d \
  -e RAILS_MASTER_KEY=<config/master.key> \
  -e DATABASE_URL=postgres://app:<password>@<db-host>:5432/app_production \
  -e REDIS_URL=redis://<redis-host>:6379/0 \
  --no-healthcheck \
  --name app-worker app bundle exec sidekiq
```

- `--no-healthcheck` on the worker: the image's baked-in `HEALTHCHECK` (`curl .../up`) assumes the
  web role — it will always fail on a worker container, which never binds port 3000.
- `config/database.yml`'s `production:` block intentionally has only a `primary` entry — no
  `cache`/`queue`/`cable` secondary databases (that's Rails 8's default solid_cache/solid_queue/
  solid_cable scaffolding; this app uses Sidekiq + Action Cable's redis adapter instead, and
  solid_cache was never actually wired up — see `docs/progress.md`'s Phase 10 section).
- See `.env.example`'s "Production only" section for the full env var list (`ADMIN_EMAIL`/
  `ADMIN_PASSWORD` for seeding, Twilio credentials for real SMS/WhatsApp, etc).
- Verified end-to-end (build, boot, migrate, seed, sign in, healthcheck) against real
  Postgres/Redis via `docker compose`'s `db`/`redis` services during Phase 10 — see
  `docs/progress.md` for the exact commands used.

## Architecture essentials

- **No Node/Yarn**: Propshaft + importmap, plain CSS with custom properties (`tokens.css`,
  planned in Phase 9). No JS build stage even in the production `Dockerfile`.
- **Auth**: Devise on `User`, `:registerable` intentionally disabled — users are only created by
  an admin through Avo, never self-signup. Roles are a separate `Role`/`UserRole` N:N (not Devise
  roles or a gem like rolify) — `Role::KEYS` in `app/models/role.rb` is the source of truth for
  valid role keys (`admin`, `registration_operator`, `expedition_operator`, `queue_operator` —
  English identifiers; the `name` column stays pt-BR since it's user-facing). Use
  `user.role?(:key)` / `user.admin?`, not direct association queries.
- **Authorization**: Pundit. `ApplicationPolicy` denies by default (`false`); every real policy
  must explicitly allow. Avo (admin panel, not yet mounted) will integrate via
  `authorization_client = :pundit` with remapped action names (`avo_index?`, `avo_update?`, etc.)
  to avoid colliding with domain-specific policy methods like `check_in?`/`issue_order?`.
- **i18n**: default and only active locale is `pt-BR` (`config/application.rb`); locale structure
  is ready for `en` later but no translations exist yet beyond Devise's.
- **Jobs/Cable**: Sidekiq + Redis (`config.active_job.queue_adapter = :sidekiq`), not Rails 8's
  default solid_queue/solid_cable — those were deliberately removed from the Gemfile in favor of
  Redis, along with `kamal`/`thruster`.
- **Notifications**: adapter pattern behind `Rails.application.config.x.notifications.adapter_class`
  (`app/models/notifications/`) — a `TestAdapter` in dev/test so no real SMS/WhatsApp is ever sent
  accidentally outside production; real `TwilioSmsAdapter`/`TwilioWhatsappAdapter` in production.
  Triggered from `Visits::IssueOrderService`/`Visits::PromoteNextService`, not a model callback.
- **Queue position is derived, not stored** — computed from `order_issued_at` ordering to avoid
  desync bugs (`Visit#queue_position` / `Visit.active_queue` in `app/models/visit.rb`).
- Two Dockerfiles: `Dockerfile` (production, multi-stage, non-root, Rails-generated) vs.
  `Dockerfile.dev` (used by `docker-compose.yml`, all gem groups + Chromium, source bind-mounted).

## Testing conventions (see `docs/plan.md` "Testing strategy" for full detail)

- `rspec-rails` + `factory_bot_rails` + `shoulda-matchers` + `pundit-matchers`; system specs use
  Capybara + Cuprite (headless Chrome via CDP — no separate driver binary needed).
- Twilio adapters are the only thing tested against stubbed HTTP (`webmock`/`vcr`); everything
  else uses the in-memory `TestAdapter`/spies — never let a spec hit the real Twilio API.
- `Role` factory uses `find_or_initialize_by(key:)` since only 4 valid keys exist as fixed
  reference data — don't change it to plain `create` semantics.
