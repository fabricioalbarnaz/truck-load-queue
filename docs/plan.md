# Truck Loading Queue Management System

## Context

The mining company currently organizes its truck loading queue manually / over radio. This causes delays, gives drivers no visibility into their position in the queue, and creates rework for operators. The goal is to build a Rails system that:

- Registers drivers and their trucks (N:N relationship, since a driver may drive different trucks on different visits).
- Controls the lifecycle of each visit: registration → yard check-in → loading order issuance → queue → loading → finished.
- Automatically notifies the driver (SMS and/or WhatsApp) when it's their turn to load.
- Displays a public, real-time screen with queue status (e.g., a monitor in the yard).
- Has 3 authenticated operational screens by role (registration, dispatch, queue) plus a full administrative panel.

This is a greenfield project in `D:\Sites`, currently empty — there is no existing code to reconcile with.

## Confirmed technical decisions

| Decision | Choice |
|---|---|
| Framework | Ruby on Rails 8.0.x (Ruby 3.3.x), Postgres |
| Real-time | Turbo Streams / ActionCable (Rails-native, no polling) |
| Individual notifications | SMS **and** WhatsApp via Twilio, configurable per driver (`sms`/`whatsapp`/`both`) |
| Admin panel | **Avo** gem (~> 3.x), authorization via Pundit |
| Auth/Roles | Single `User` model (Devise) + `Role`/`UserRole` (N:N) — roles: `admin`, `cadastro` (registration), `expedicao` (dispatch), `fila` (queue) |
| Driver↔Truck link | Fixed N:N registration (`DriverTruck`), and each visit (`Visit`) records which truck was used on that occasion |
| Queue order | Simple FIFO by order-issuance timestamp (`order_issued_at`) — no manual reordering |
| Yard check-in | Separate action from registration (a driver may visit the mine multiple times over time) |
| Languages (i18n) | pt-BR only in v1, but locale structure ready to add languages later |
| Jobs / message queue | Redis + Sidekiq (async notification delivery, with retry) |
| Visit cancellation | **Out of scope for v1** — see "Future improvements" |
| Sensitive data (CPF/phone) | Encrypted at rest via `ActiveRecord::Encryption` (LGPD) |

## Stack and key gems

- **Auth**: `devise` + `devise-i18n` (pt-BR translations ready). `:registerable` disabled — users are created only by an admin via Avo, no self-signup.
- **Authorization**: `pundit` + `pundit-matchers` (specs)
- **Admin**: `avo` (~> 3.x), authorization via Pundit (`authorization_client = :pundit`)
- **Realtime**: `turbo-rails`, `stimulus-rails`
- **Jobs/Cable**: `sidekiq` + `redis` (cable.yml uses the redis adapter)
- **Notifications**: `twilio-ruby`, `phonelib` (E.164 validation)
- **Document validation**: `cpf_cnpj`
- **Env**: `dotenv-rails` (dev/test), Rails credentials in production
- **Testing**: `rspec-rails`, `factory_bot_rails`, `faker`, `shoulda-matchers`, `capybara` + `cuprite` (headless Chrome via CDP, no external driver dependency), `webmock`/`vcr` (stub Twilio calls — no test ever hits the real API)
- **Styling**: no Node/Yarn — Rails 8 uses Propshaft + importmap, plain CSS with custom properties (`tokens.css`) for easy theme customization
- **Lint**: `rubocop-rails-omakase`

## Data model

```
User ──< UserRole >── Role
Driver ──< DriverTruck >── Truck
Driver ──< Visit >── Truck
Visit  >── User (checked_in_by / order_issued_by / finished_by)
```

- **`users`**: standard Devise + `name`. No `:registerable`.
- **`roles`**: `key` (admin/cadastro/expedicao/fila), `name`. Seeded in `db/seeds.rb`.
- **`user_roles`**: join table, unique index `[user_id, role_id]`.
- **`drivers`**: `name`, `cpf` (encrypted, unique, validated via `cpf_cnpj`), `phone` (encrypted, E.164 via `phonelib`), `notification_channel` enum (`sms`/`whatsapp`/`both`), `active`.
- **`trucks`**: `plate` (unique, uppercase), `model`, `capacity`, `active`.
- **`driver_trucks`**: fixed N:N join, unique index `[driver_id, truck_id]`, `active` (soft-disable without deleting history).
- **`visits`** (the "check-in"/occurrence record): `driver_id`, `truck_id`, `status` enum (`in_yard`, `queued`, `loading`, `finished`), `entered_yard_at`, `order_issued_at` (FIFO sort key), `loading_started_at`, `finished_at`, `checked_in_by_id`, `order_issued_by_id`, `finished_by_id` (audit FKs to User).

**Queue position is derived, not stored** (avoids desync bugs):
```ruby
scope :active_queue, -> { where(status: [:queued, :loading]).order(:order_issued_at) }
def queue_position
  return 0 if loading?
  Visit.where(status: :queued).where("order_issued_at < ?", order_issued_at).count + 1
end
```

Validation: only one active visit (`in_yard`/`queued`/`loading`) per truck and per driver at a time.

If an operator registers a driver+truck combination that doesn't yet exist in `driver_trucks`, the check-in service creates that pairing first (upsert), keeping `driver_trucks` as the single source of truth for "who has driven which truck."

## State machine

| Transition | Trigger | Role | Service |
|---|---|---|---|
| — → `in_yard` | Yard check-in | `cadastro` | `Visits::CheckInService` |
| `in_yard` → `queued` or `loading` | Order issuance | `expedicao` | `Visits::IssueOrderService` |
| `loading` → `finished` | Loading finished | `fila` | `Visits::FinishLoadingService` |
| `queued` → `loading` (next) | Automatic | system | `Visits::PromoteNextService` |

There is no manual "start loading" button: when an order is issued, if the queue is empty the visit goes straight to `loading` (it's already the truck's turn); otherwise it becomes `queued`. When finished, `PromoteNextService` promotes the next `queued` visit by `order_issued_at` to `loading`.

Implemented with plain `enum` + guarded methods in service objects (no state-machine gem — only 3 real transitions, not enough complexity to justify `aasm`).

## Real-time (Turbo Streams)

`after_commit` on the `Visit` model, firing on any relevant status change (including edits made via the Avo admin):
```ruby
after_commit :broadcast_public_queue!, if: :queue_relevant_change?

def broadcast_public_queue!
  Turbo::StreamsChannel.broadcast_replace_to(
    "public_queue", target: "public_queue", partial: "public/queue/board",
    locals: { loading: Visit.loading.first, queued: Visit.active_queue.queued }
  )
end
```
Broadcasting lives on the model (it's a UI concern, should reflect any state change); notification sending stays explicit inside the services (it's a business event, independently testable).

## Notifications (SMS + WhatsApp)

```
app/services/notifications/
  dispatcher.rb              # picks adapter(s) based on driver.notification_channel
  notify_driver_service.rb   # builds message copy per event type, calls Dispatcher
  adapters/base_adapter.rb, twilio_sms_adapter.rb, twilio_whatsapp_adapter.rb, test_adapter.rb
app/jobs/send_notification_job.rb
```

- `Notifications::Dispatcher` routes to 1 or 2 adapters depending on the driver's channel.
- The adapter used is resolved via config (`Rails.application.config.x.notifications.adapter_class`): `TestAdapter` (records in memory/log) in dev/test, real Twilio adapters in production — no real SMS is ever sent accidentally in development.
- v1 only fires the `:your_turn` event (when a visit enters `loading`), asynchronously via `SendNotificationJob` (Sidekiq, with retry).
- The structure is already prepared to add `:order_issued` and `:getting_close` as additive future improvements.

## Authorization (Pundit) + Avo

- `ApplicationPolicy` base with an `admin?` helper.
- `VisitPolicy` with domain actions: `check_in?` (cadastro), `issue_order?` (expedicao), `finish?` (fila), always also allowed for `admin`.
- Avo 3 integrates natively with Pundit (`authorization_client = :pundit`). Methods are remapped (`avo_index?`, `avo_update?`, etc.) to avoid colliding with the domain actions on the policies — only `admin` can reach `/admin`, with a double gate: `authenticate_with` at the mount point + per-resource policy.
- `UserResource` in Avo exposes `roles` assignment (multi-select field) — this is the requested "permission management."

## Docker

Single `Dockerfile` (no Node stage — Propshaft + importmap remove the need for a JS build):
- Ruby 3.3-slim, `bundle install`, `bootsnap precompile`, Rails' default entrypoint (`db:prepare` on boot).

`docker-compose.yml`: services `db` (postgres:16-alpine), `redis` (redis:7-alpine), `web` (rails server), `worker` (sidekiq). `.env` (gitignored) for `DATABASE_URL`, `REDIS_URL`, Twilio credentials, `RAILS_MASTER_KEY`.

The final project phase includes production hardening: multi-stage Dockerfile, non-root user, healthchecks, `RAILS_LOG_TO_STDOUT`.

## Testing strategy

- **Models**: validations, associations, enums, scopes (`active_queue`, `queue_position`), CPF/phone encryption.
- **Policies**: one spec per policy using `pundit-matchers`, covering all 4 roles + unauthenticated.
- **Services** (highest value): `CheckInService`, `IssueOrderService` (empty vs non-empty queue), `FinishLoadingService` (promotes the next visit by `order_issued_at`, not creation order), `Notifications::Dispatcher` (sms/whatsapp/both routing).
- **Request specs**: one per controller/role — 302 if unauthenticated, 302/403 if wrong role, 200 + correct state change if authorized. Includes `public/queue` with no auth.
- **System specs** (Capybara + Cuprite, JS enabled): full flow check-in → issue order → finish, using two simultaneous Capybara sessions (one operator, one "public") to observe the Turbo Stream update genuinely live.
- Twilio adapters are tested in isolation with `webmock`/`vcr`; everything else uses `TestAdapter`/spies.

## File structure (key files)

```
app/models/{user,role,user_role,driver,truck,driver_truck,visit}.rb
app/policies/{application,driver,truck,driver_truck,visit,user,role}_policy.rb
app/services/visits/{check_in,issue_order,finish_loading,promote_next}_service.rb
app/services/notifications/{dispatcher,notify_driver_service}.rb
app/services/notifications/adapters/{base,twilio_sms,twilio_whatsapp,test}_adapter.rb
app/jobs/send_notification_job.rb
app/controllers/cadastro/{drivers,trucks,visits}_controller.rb
app/controllers/expedicao/visits_controller.rb
app/controllers/fila/visits_controller.rb
app/controllers/public/queue_controller.rb
app/views/{cadastro,expedicao,fila,public}/**/*.html.erb
app/assets/stylesheets/tokens.css, application.css, components/*.css
app/avo/resources/{user,role,driver,truck,driver_truck,visit}_resource.rb
config/initializers/{devise,avo,twilio,sidekiq}.rb
config/locales/{pt-BR,devise.pt-BR}.yml
db/migrate/*, db/seeds.rb (4 roles + 1 admin user)
Dockerfile, docker-compose.yml, .env.example
spec/{models,policies,services,jobs,requests,system}/**/*_spec.rb, spec/factories/*.rb
```

## Version control (Git)

The project uses **git** from the very first commit:

- `git init` at the root (`D:\Sites`) as part of Phase 1, before/alongside `rails new`.
- `.gitignore` generated by `rails new` itself (adjusted to exclude `.env`, `master.key`, Docker log/tmp files).
- `.env.example` **is** version-controlled (no real secrets); the real `.env` stays out of git.
- One commit per milestone/phase from the "Build phases" section below, to keep a reviewable, incremental history.
- A single main branch (`main`) is sufficient for this project — no need for a formal branching strategy in v1, given team size.

## Documentation (`docs/` folder)

As part of Phase 1, a `docs/` folder is created at the project root containing:

- `docs/plan.md` — this file: the full implementation plan in English, serving as the architecture reference for the team.

## Build phases (incremental milestones)

1. **Skeleton**: `git init`, create `docs/plan.md` (this file), `rails new` (Postgres, plain CSS), working Docker/compose, Devise + Pundit, `User`/`Role`/`UserRole` models, seed roles + admin, default locale pt-BR. *Verify*: boots via `docker compose up`, admin can log in, `git log` shows the initial history.
2. **Driver/Truck registration**: `Driver`, `Truck`, `DriverTruck` models + policies + `Cadastro::DriversController`/`TrucksController` + views. *Verify*: a `cadastro` operator can CRUD; other roles get a 302.
3. **Yard check-in**: `Visit` + `CheckInService` + yard listing. *Verify*: check-in creates an `in_yard` visit; duplicates are blocked.
4. **Dispatch screen**: `IssueOrderService`, `Expedicao::VisitsController` (yard + queue view). *Verify*: empty queue → `loading`; non-empty queue → `queued`, correct order.
5. **Queue screen**: `FinishLoadingService` + `PromoteNextService`, `Fila::VisitsController`. *Verify*: finishing promotes the correct next visit by `order_issued_at`.
6. **Public real-time screen**: `Public::QueueController` + Turbo Streams broadcast. *Verify*: two open tabs, an action in one reflects in the other without a refresh.
7. **Notifications**: Dispatcher + adapters + Sidekiq job, fired when entering `loading`. *Verify*: `TestAdapter` logs in dev; VCR-backed specs pass without hitting the real network.
8. **Avo admin panel**: resources for all 6 models, Pundit integration, role assignment. *Verify*: a non-admin is redirected away from `/admin`; an admin can create a user and assign a role.
9. **Test coverage + styling**: close spec gaps, `tokens.css` pass (colors/spacing/typography as custom properties), responsive layout for the yard monitor (large typography). *Verify*: `bundle exec rspec` green.
10. **Production hardening**: multi-stage Dockerfile, non-root user, secrets via `RAILS_MASTER_KEY`, healthchecks.

## Future improvements (out of v1 scope)

- **Visit cancellation**: a truck leaves the yard/queue without loading (mechanical issue, gave up, etc.). Will require a new `cancelled` status, a decision on which role can cancel, and UI on the dispatch/queue screens.
- Notifications for `:order_issued` and `:getting_close` (when N trucks remain before the driver's turn).
- Multiple yards/sites, in case the mining company operates more than one unit.
- Additional language (en) — locale structure is already prepared, only translation is missing.

## Assumptions (confirm if they diverge from real-world operations)

- A single yard/site (no multi-tenant units).
- The public screen shows the driver's full name + plate — assumed acceptable since it's an internal yard monitor, not internet-facing.
- No operator self-signup (only an admin creates users via Avo).

## End-to-end verification

- `docker compose up` brings up `web`, `worker`, `db`, `redis` with no errors.
- Log in as each role (`cadastro`, `expedicao`, `fila`, `admin`) and confirm access only to the screens allowed for that role.
- Full manual flow: register driver+truck → yard check-in → issue order (dispatch) → confirm the public screen updates live → finish loading (queue) → confirm automatic promotion of the next truck and the "TestAdapter" notification firing in the logs.
- `bundle exec rspec` (inside the container) with the whole suite green.
- Visit `/admin`, create a new user and assign a role, confirm they can log in to the corresponding screen.
