# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Rails 8 app for a mining company's truck loading queue management system (registration → yard
check-in → order issuance → queue → loading → finished, with SMS/WhatsApp notifications and a
public real-time screen). Greenfield, built incrementally in 10 phases.

**This file is the architecture/design reference** (data model essentials, state machine,
notifications design, authorization design, testing conventions, file layout) — read it in full
before making changes. **Read `docs/software-evolution.md` second** — it is the execution/history
log, updated at the end of every completed phase, showing what's actually implemented and
documenting deviations from the original design discovered along the way (e.g. Avo resolved to
v4.x, not the 3.x originally assumed).

All 10 original build phases are done (skeleton; Driver/Truck registration; Visit/check-in;
dispatch; queue; public Turbo Streams screen; notifications; Avo admin; test/styling pass;
production hardening) — this is a complete v1, not a work-in-progress, plus several post-v1 rounds
of work since (inline driver/truck registration on check-in, an events ingestion pipeline, this
Railway test deployment, order numbers on visits). See `docs/software-evolution.md` for the full
execution log, including deviations from the original design discovered along the way (e.g. the
`Queue::` module was renamed to `QueueScreen::` because it collides with Ruby's stdlib `Queue`
class; Avo's Pundit integration, `avo-authorization`, turned out to be a paid plugin, so `/admin`
uses a single admin-only `authenticate_with` gate instead). Remaining work is explicitly out of v1
scope — see this file's "Product scope" section below (visit cancellation, additional notification
events, multi-site support, `en` locale) and `docs/software-evolution.md`'s "Project status"
section (what a real production deploy would still need: real Postgres/Redis host,
`config.hosts`, a provisioned `RAILS_MASTER_KEY`, real Twilio credentials).

When completing a phase, update `docs/software-evolution.md` (status table + a new phase section)
the same way Phase 1 was documented, so the next session can resume without rebuilding context.

## Product scope

**Future improvements (explicitly out of v1 scope)**:
- **Visit cancellation**: a truck leaves the yard/queue without loading (mechanical issue, gave up,
  etc.). Will require a new `cancelled` status, a decision on which role can cancel, and UI on the
  dispatch/queue screens.
- Notifications for `:order_issued` and `:getting_close` (when N trucks remain before the driver's
  turn).
- Multiple yards/sites, in case the mining company operates more than one unit.
- Additional language (`en`) — locale structure is already prepared, only translation is missing.

**Assumptions (confirm if they diverge from real-world operations)**:
- A single yard/site (no multi-tenant units).
- The public screen shows the driver's full name + plate — assumed acceptable since it's an
  internal yard monitor, not internet-facing.
- No operator self-signup (only an admin creates users via Avo).

## Workflow for code changes

Before writing any code, break the requested change into a short numbered list of concrete
implementation steps and present it to the user. Do not start implementing until the user approves
the plan. This applies to every code change in this repo, not just large features — a one-line fix
still gets a (possibly one-step) plan stated up front.

As soon as the plan is approved, write it to `docs/plans/<short-feature-name>.md` (kebab-case,
descriptive of the change — e.g. `docs/plans/visit-cancellation.md`) as a checklist, one line per
step, before implementing step 1. This is what makes the plan survive a lost session (closed
terminal, PC restart, corrupted/deleted session transcript) — a new session can resume purely by
reading this file, without needing to resume the exact prior conversation. After each step is
approved and done, check it off (`- [x]`) in the file as part of that step's changes, so the file
always reflects true progress, not just intent.

Once every step is checked off, the plan file has done its job — fold anything worth keeping
long-term into `docs/software-evolution.md`, then delete the file from `docs/plans/`. Don't let
finished plans pile up there.

Then implement **one step at a time**: after finishing a step, stop and report what changed before
moving on, and wait for the user's explicit approval before starting the next step. Never batch
multiple unapproved steps together. If a step turns out to need revision mid-way (e.g. an approved
step's approach doesn't pan out), stop, update the plan file to reflect the new steps, and
re-propose rather than silently improvising a replacement.

This is stricter than Claude Code's built-in plan mode (which only asks for approval once, on the
plan as a whole, then executes every step autonomously) — the per-step checkpoint is the point,
since it's what lets the user catch a wrong turn before it compounds into the next step.

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

**Windows executable-bit note**: NTFS has no real Unix executable bit, so `bin/*` scripts
(`bin/rails`, `bin/docker-entrypoint`, etc. — required executable for the Dockerfile's
`ENTRYPOINT`/`CMD` to run at all) can silently lose their `755` mode on this platform. A plain
`git add`/GUI "stage all" re-derives the mode from the filesystem (always `644` here) and reverts
any fix. The only sequence that sticks: `git update-index --chmod=+x <files>` immediately followed
by `git commit`, with nothing else touching those files in between. `git status`/`git diff` will
keep showing the working-tree copy as `644` afterward (`MM` status) — that's cosmetic, since a
commit captures the index (`755`), not the working tree; don't "fix" it by re-staging.

### End-to-end verification checklist

- `docker compose up` brings up `web`, `worker`, `db`, `redis` with no errors.
- Log in as each role (`registration_operator`, `expedition_operator`, `queue_operator`, `admin`)
  and confirm access only to the screens allowed for that role.
- Full manual flow: register driver+truck → yard check-in → issue order (dispatch, with an order
  number) → confirm the public screen updates live → finish loading (queue) → confirm automatic
  promotion of the next truck and the "TestAdapter" notification firing in the logs.
- `bundle exec rspec` (inside the container) with the whole suite green.
- Visit `/admin`, create a new user and assign a role, confirm they can log in to the corresponding
  screen.
- `docker build -t app .` succeeds, and the resulting image boots correctly in both roles (web via
  its default `CMD`, worker via `bundle exec sidekiq`) against real Postgres/Redis — see this
  file's Production section for the exact commands, and `docs/software-evolution.md`'s Phase 10
  section for what was actually verified.

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
  solid_cache was never actually wired up — see `docs/software-evolution.md`'s Phase 10 section).
- See `.env.example`'s "Production only" section for the full env var list (`ADMIN_EMAIL`/
  `ADMIN_PASSWORD` for seeding, Twilio credentials for real SMS/WhatsApp, etc).
- Verified end-to-end (build, boot, migrate, seed, sign in, healthcheck) against real
  Postgres/Redis via `docker compose`'s `db`/`redis` services during Phase 10 — see
  `docs/software-evolution.md` for the exact commands used.

### Live test env (Railway)

A free, throwaway test deployment exists on Railway (`adequate-analysis` project,
`truck-load-queue` web service + `spirited-dream` worker service + `Postgres`/`Redis` plugins,
branch `test`) — `https://truck-load-queue-production.up.railway.app`. Verified end-to-end
(sign-in, check-in, dispatch, queue, live public-screen updates via Action Cable). No code changes
were needed beyond fixing the `bin/*` executable-bit bug above — `config/puma.rb`'s
`ENV.fetch("PORT", 3000)` and Sidekiq's default Redis resolution both already picked up Railway's
injected `PORT`/`REDIS_URL` with zero config. Provisioned via the dashboard, not config-as-code — a
repo-root `railway.toml`'s `startCommand` would conflict across the web/worker split, since Railway's
documented pattern for "web + worker from one repo" is two services, each with its own Start
Command set individually.

**Env vars — web service:**

| Variable | Value | Why |
|---|---|---|
| `RAILS_MASTER_KEY` | contents of local `config/master.key` | Decrypts `config/credentials.yml.enc`, including the `active_record_encryption` keys `Driver#cpf`/`Driver#phone` need. Wrong value = boot fails immediately. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | `config/database.yml`'s production block merges `DATABASE_URL` on top of its `username`/`password` fields — this alone is sufficient. |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Feeds `config/cable.yml`'s production `redis` adapter (Action Cable) and Sidekiq's default connection resolution. |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | your choice | Seed admin login (`db/seeds.rb`); falls back to `admin@example.com`/`changeme123` if unset. |
| `EVENTS_INGEST_TOKEN` | random string (e.g. `openssl rand -hex 32`) | Only gates `/api/events`; harmless to set even if unused. |
| `TWILIO_ACCOUNT_SID`/`TWILIO_AUTH_TOKEN`/`TWILIO_SMS_FROM`/`TWILIO_WHATSAPP_FROM` | leave unset, or real/trial values | See known limitation below — deliberate, not an oversight. |

Don't set `RAILS_ENV` (baked into the Dockerfile) or `PORT` (Railway injects it).

**Env vars — worker service**: same `RAILS_MASTER_KEY`/`DATABASE_URL`/`REDIS_URL`/`TWILIO_*` values
as web (must match — the real Twilio call happens in this process, via `SendNotificationJob`). Do
**not** set `EVENTS_INGEST_TOKEN`/`ADMIN_EMAIL`/`ADMIN_PASSWORD` here — irrelevant to a process that
never serves HTTP or seeds. Start Command is `bundle exec sidekiq` — this overrides the image's
`ENTRYPOINT` entirely (not just `CMD`), so the worker skips `bin/docker-entrypoint`'s `db:prepare`
call completely (confirmed via logs showing no migration output). The web service's Start Command
stays blank so `db:prepare` keeps running there on every boot.

**Manual redeploy workflow** (auto-deploy is off on both services — a hand-driven test env benefits
from explicit control over *when* a redeploy happens):

- *Dashboard*: push commits to the watched branch, then in Railway open the **web** service →
  Deployments → "Deploy"/"Redeploy" (rebuilds, reruns `db:prepare` so any new migration applies),
  then redeploy the **worker** service the same way so both run the same commit. Watch each
  service's deploy logs — build succeeds, `db:prepare` output on web only, healthcheck green —
  before considering the update live.
- *CLI*: `railway login` + `railway link` once per local clone, then `railway up --service web`
  (and separately `--service worker`) deploys straight from the local working tree without a git
  push first — useful for testing an uncommitted change, but commit/push once it's confirmed good
  so the repo stays the source of truth.
- Either way, re-run the relevant part of the End-to-end verification checklist above after each
  redeploy — a green build/healthcheck only confirms the app booted, not that the feature being
  tested actually works.

**Known limitation**: `TWILIO_*` env vars are left unset — `config/initializers/notifications.rb`
picks the adapter purely off `Rails.env.production?`, so this deploy always resolves to the real
Twilio adapters, never the safe `TestAdapter`. Checking in/issuing orders/finishing loads all still
work normally (notification enqueue is fully decoupled via Sidekiq); only the async
`SendNotificationJob` fails when the worker picks it up, retries 5x with polynomial backoff, then
dies — cosmetic worker-log noise only, never blocks the UI.

**Cost/lifespan**: Railway's Trial plan — no card required, one-time $5 credit, consumed by actual
per-second usage across all 4 services, expires 30 days after signup or when exhausted (whichever
first). Expect roughly 1–3 weeks of continuous 24/7 running for this app's low-traffic footprint;
stop all 4 services from the dashboard between test sessions to stretch it further. This is
explicitly a throwaway test env, not a durable host — default to decommissioning when it runs out
rather than adding a card, unless told otherwise at that point.

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
  must explicitly allow. `ApplicationPolicy` also defines `avo_*` methods (`avo_index?`,
  `avo_update?`, etc., remapped to avoid colliding with domain-specific policy methods like
  `check_in?`/`issue_order?`), but they're dormant — Avo 4's Pundit integration
  (`avo-authorization`) turned out to be a paid plugin, so `/admin` is actually gated by a single
  admin-only `authenticate_with` check instead (see `docs/software-evolution.md`'s Phase 8 section).
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

### Events ingestion (device webhooks)

A generic pipeline lets external devices — starting with a gate camera reading license plates —
push events into the app without hard-wiring any one device into domain logic
(`app/models/event.rb`, `app/controllers/api/`, `app/services/events/`, `app/jobs/events/`).

```
POST /api/events
Authorization: Bearer <EVENTS_INGEST_TOKEN>
Content-Type: application/json

{ "event_type": "truck_detected", "device_id": "gate-cam-01",
  "occurred_at": "2026-08-06T14:32:10Z", "data": { "plate": "ABC1D23", "confidence": 0.97 } }

→ 202 { "id": 123, "status": "pending" }
```

- **Auth**: a single shared-secret Bearer token, `ENV["EVENTS_INGEST_TOKEN"]`, checked via
  `ActiveSupport::SecurityUtils.secure_compare` in `Api::BaseController` (`< ActionController::API`,
  not `ApplicationController` — sidesteps `allow_browser versions: :modern` and never has CSRF
  protection to begin with). Missing/wrong token → `401`.
- **Accept-and-fail-async**: the endpoint always persists the `Event` and enqueues
  `Events::ProcessEventJob` for any non-blank `event_type` (→ `202`), even one with no registered
  processor — an unrecognized type is discovered and marked `failed` by the job, not rejected at
  the network boundary. Only a structurally invalid request (e.g. blank `event_type`) gets `422`.
- **Adding a new event type**: register a `"event_type" => ProcessorClass` entry in
  `Events::Registry::PROCESSORS` (a frozen, **String**-keyed hash — `event_type` is untrusted
  external input, not an internal symbol literal). Each processor is a plain
  `initialize(event:)` + `#call` object, no shared base class.
- **Current state**: only `"truck_detected"` is registered, and `TruckDetectedProcessor` is a
  **stub** — it logs and returns, and deliberately does **not** create a `Visit` or call
  `Visits::CheckInService`. Wiring a detected truck to an actual check-in is explicit future work,
  not done yet.
- The exact request field names/nesting above are a placeholder to unblock building the pipeline —
  confirm against the real device/vendor's actual POST format before wiring a real camera to this
  endpoint.

## Testing conventions

- `rspec-rails` + `factory_bot_rails` + `shoulda-matchers` + `pundit-matchers`; system specs use
  Capybara + Cuprite (headless Chrome via CDP — no separate driver binary needed).
- **Models**: validations, associations, enums, scopes (`active_queue`, `queue_position`), CPF/phone
  encryption.
- **Policies**: one spec per policy using `pundit-matchers`, covering all 4 roles + unauthenticated.
- **Services** (highest value): `CheckInService`, `IssueOrderService` (empty vs. non-empty queue),
  `FinishLoadingService` (promotes the next visit by `order_issued_at`, not creation order),
  `Notifications::Dispatcher` (sms/whatsapp/both routing).
- **Request specs**: one per controller/role — 302 if unauthenticated, 302/403 if wrong role, 200 +
  correct state change if authorized. Includes `public/queue` with no auth.
- **System specs** (Capybara + Cuprite, JS enabled): full flow check-in → issue order → finish,
  using two simultaneous Capybara sessions (one operator, one "public") to observe the Turbo Stream
  update genuinely live (`spec/system/visit_lifecycle_spec.rb`) — see `docs/software-evolution.md`'s
  Phase 9 section for the driver-name collision, `DatabaseCleaner` requirement, and other gotchas
  hit getting this infrastructure working. Register the Cuprite driver under a name other than
  `:cuprite` (e.g. `:app_cuprite`) — `capybara-cuprite`'s own default `:cuprite` registration wins
  over a same-named override under full RSpec/Rails boot.
- Twilio adapters are the only thing tested against stubbed HTTP (`webmock`/`vcr`); everything
  else uses the in-memory `TestAdapter`/spies — never let a spec hit the real Twilio API.
- `Role` factory uses `find_or_initialize_by(key:)` since only 4 valid keys exist as fixed
  reference data — don't change it to plain `create` semantics.
