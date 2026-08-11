# Events ingestion — base infrastructure

> Status: **planned, not yet implemented**. This is a design document for an upcoming feature,
> written before any code exists. Once implemented, fold the relevant parts into `docs/plan.md`
> (architecture reference) and log the work in `docs/progress.md` (execution log), per
> `CLAUDE.md`'s documentation convention — this file can be deleted or left as historical context
> at that point.

## Context

The mining company wants a camera to read a truck's license plate and automatically start a
`Visit`, instead of an operator manually checking the truck in at `/registration/visits`. This is
the first of what will become several device/event-driven triggers into this system, so rather
than hard-wiring "camera POST → CheckInService" directly, we're building a generic events
ingestion pipeline first: a persisted `Event` record, a machine-authenticated ingestion endpoint,
an event-type registry, and async processing — with `truck_detected` registered as a **stub**
handler only (logs and returns; does **not** create a `Visit` or touch
`Visits::CheckInService`). Wiring `truck_detected` to actually start a visit is an explicit,
separate follow-up plan.

This codebase has no existing precedent for machine-to-machine auth, JSON API controllers, or a
JSONB column — all confirmed via direct reads of `config/routes.rb`,
`app/controllers/application_controller.rb`, `app/services/notifications/notify_driver_service.rb`,
`app/jobs/send_notification_job.rb`, `app/services/visits/check_in_service.rb`, and
`config/environments/test.rb`. The design below deliberately mirrors this app's existing
conventions (service `.new(kwargs).call` shape, thin ID-only jobs with `retry_on`, frozen-hash
event registries) everywhere they apply, and calls out the few places (JSONB payload, API
namespace, shared-secret auth) that are genuinely new territory for this codebase.

**Decisions confirmed with the user:**
- Scope: infra only. `truck_detected` is a no-op/logging stub; starting a real `Visit` is future work.
- Auth: single shared-secret Bearer token via `ENV["EVENTS_INGEST_TOKEN"]`, read inline (matches
  the Twilio-adapter pattern of reading secrets directly in the consuming class, not a
  `config/initializers/*.rb`/`config.x` indirection). Not per-device DB-backed API keys.
- Unknown `event_type`: **accept and fail async** — the endpoint always persists the `Event` and
  enqueues the job for any non-blank `event_type`; the job discovers it's unregistered and marks
  the row `failed`. Nothing is silently dropped at the network boundary.
- No `external_id`/idempotency column in this phase — schema stays minimal to what's needed now.
- No Avo resource for `Event` in this phase — admin visibility via `bin/rails console`/DB for now.

## Implementation

### 1. Migration + model

`db/migrate/<timestamp>_create_events.rb`:
```ruby
create_table :events do |t|
  t.string   :event_type,  null: false
  t.string   :status,      null: false, default: "pending"
  t.string   :device_id
  t.jsonb    :payload,     null: false, default: {}
  t.datetime :received_at, null: false
  t.datetime :occurred_at
  t.datetime :processed_at
  t.text     :error_message
  t.timestamps
end
add_index :events, :event_type
add_index :events, [ :event_type, :status ]
add_index :events, :received_at
```
- `payload` as `jsonb` is a first for this schema (no extension needed on modern Postgres) —
  deliberate, since payload shape varies per `event_type` and shouldn't be forced into discrete
  columns at this generic layer.
- `received_at` (when this app accepted the request) is kept distinct from `occurred_at` (the
  device's own reported detection time, nullable, parsed from the payload if present) and from
  `created_at` (DB insert time) — avoids conflating these if a device ever batches/delays delivery.
- No FK/association fields — `Event` is infrastructure, not a domain entity; `device_id` is a
  plain string, not a `belongs_to` (no `Device` table in this design).
- No `external_id`/idempotency column per the confirmed decision above.

`app/models/event.rb`:
```ruby
class Event < ApplicationRecord
  enum :status, { pending: "pending", processed: "processed", failed: "failed" }, default: "pending"

  validates :event_type, presence: true
  validates :received_at, presence: true

  scope :for_type, ->(event_type) { where(event_type: event_type) }
end
```
Same string-backed-enum-with-default shape as `Visit#status`. No `after_commit` callback to
enqueue processing (unlike `Visit#broadcast_public_queue!`) — enqueuing is done explicitly by the
ingestion service, mirroring how `NotifyDriverService.enqueue` is called explicitly from
`IssueOrderService`/`PromoteNextService` rather than from a model callback.

### 2. Ingestion endpoint

`config/routes.rb` — add:
```ruby
namespace :api do
  resources :events, only: %i[create]
end
```
`POST /api/events` → `Api::EventsController#create`. New `api` namespace (not `events`) since this
names the transport/audience (machine-facing JSON), consistent with how `registration`/
`expedition`/`queue`/`public` each name a human actor/screen — leaves room for future non-event
API endpoints without renaming.

`app/controllers/api/base_controller.rb`:
```ruby
module Api
  class BaseController < ActionController::API
    before_action :authenticate_device!

    private

    def authenticate_device!
      head :unauthorized and return if expected_token.blank?

      token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
      head :unauthorized and return if token.blank?
      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
    end

    def expected_token
      ENV["EVENTS_INGEST_TOKEN"]
    end
  end
end
```
Inherits `ActionController::API`, **not** `ApplicationController` — sidesteps `allow_browser
versions: :modern` (which would 406 a non-browser device client) entirely, and `ActionController::API`
never includes CSRF protection in the first place, so there's no `skip_forgery_protection` call
needed anywhere (cleaner than disabling two behaviors on `ApplicationController`).
`ActiveSupport::SecurityUtils.secure_compare` is timing-safe for attacker-controlled input in
modern Rails (hashes both operands first).

`app/controllers/api/events_controller.rb`:
```ruby
module Api
  class EventsController < BaseController
    def create
      event = Events::IngestEventService.new(
        event_type: params[:event_type],
        device_id: params[:device_id],
        occurred_at: params[:occurred_at],
        payload: params.fetch(:data, {}).to_unsafe_h
      ).call

      if event.persisted?
        render json: { id: event.id, status: event.status }, status: :accepted
      else
        render json: { errors: event.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
```
- 202 on success (record persisted synchronously, processing is async) with a minimal body.
- 401 (empty body) on auth failure, handled entirely in `authenticate_device!`.
- 422 with `errors` only for structurally invalid input (e.g. blank `event_type`) — an
  *unrecognized-but-present* `event_type` still returns 202 per the accept-and-fail-async decision.
- `payload` (the device's own data blob) is taken via `to_unsafe_h` and stored verbatim into the
  `jsonb` column rather than strong-params-allowlisted — deliberate: this generic layer doesn't
  enforce per-event-type payload shape, each processor validates its own slice. Safe because the
  endpoint is already gated by `authenticate_device!` before this code ever runs.

Proposed (provisional — not from an actual vendor spec) request/response contract:
```
POST /api/events
Authorization: Bearer <EVENTS_INGEST_TOKEN>
Content-Type: application/json

{ "event_type": "truck_detected", "device_id": "gate-cam-01",
  "occurred_at": "2026-08-06T14:32:10Z", "data": { "plate": "ABC1D23", "confidence": 0.97 } }

→ 202 { "id": 123, "status": "pending" }
```
Flag for whoever configures the real camera: field names/nesting above are a placeholder to
unblock building the pipeline now — confirm against the actual device/vendor's real POST format
before wiring a real camera to this endpoint, and adjust `EventsController#create`'s param
extraction if it differs (e.g. if the device can't send a custom `event_type` at all, this may
need to become a per-device-type route instead of one generic endpoint).

`app/services/events/ingest_event_service.rb`:
```ruby
module Events
  class IngestEventService
    def initialize(event_type:, payload:, device_id: nil, occurred_at: nil)
      @event_type = event_type.to_s
      @payload = payload
      @device_id = device_id
      @occurred_at = occurred_at
    end

    def call
      event = Event.new(
        event_type: @event_type, payload: @payload, device_id: @device_id,
        occurred_at: parsed_occurred_at, received_at: Time.current
      )
      Events::ProcessEventJob.perform_later(event_id: event.id) if event.save
      event
    end

    private

    def parsed_occurred_at
      Time.zone.parse(@occurred_at.to_s) if @occurred_at.present?
    rescue ArgumentError
      nil
    end
  end
end
```
Same shape as `Visits::CheckInService`: builds, saves, always returns the record (valid or not);
controller branches on `.persisted?`. Enqueue only fires on successful save, matching how
`NotifyDriverService.enqueue` is only called when the triggering save succeeded.

### 3. Event-type registry

`app/services/events/registry.rb`:
```ruby
module Events
  class UnknownEventTypeError < StandardError; end

  class Registry
    PROCESSORS = {
      "truck_detected" => Events::Processors::TruckDetectedProcessor
    }.freeze

    def self.processor_for(event_type)
      PROCESSORS.fetch(event_type.to_s) do
        raise UnknownEventTypeError, "no processor registered for event_type=#{event_type.inspect}"
      end
    end
  end
end
```
Mirrors `NotifyDriverService::MESSAGES`'s frozen-hash-with-`.fetch` pattern, but **String**-keyed
(not Symbol) since `event_type` is untrusted external input from a device's JSON body, not an
internal call-site literal — avoids coercing arbitrary external strings to Symbols and matches the
DB column type 1:1. Raises a dedicated `Events::UnknownEventTypeError` so the job can distinguish
"permanently unprocessable" from "processor blew up transiently, worth retrying."

### 4. Async processing job

`app/jobs/events/process_event_job.rb`:
```ruby
module Events
  class ProcessEventJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(event_id:)
      event = Event.find(event_id)
      Events::Registry.processor_for(event.event_type).new(event: event).call
      event.update!(status: :processed, processed_at: Time.current, error_message: nil)
    rescue Events::UnknownEventTypeError => e
      event.update!(status: :failed, error_message: e.message) # permanent, no retry
    rescue StandardError => e
      event&.update!(status: :failed, error_message: e.message)
      raise # re-raise so retry_on's polynomial backoff still engages
    end
  end
end
```
Same shape as `SendNotificationJob`: `perform` takes only `event_id:`, re-fetches, delegates
immediately, same `retry_on StandardError, wait: :polynomially_longer, attempts: 5`. Note: during a
retry sequence, `status` reads `failed` between attempts even though another attempt is scheduled
— accepted simplification for this phase (no `retrying` status/attempts counter yet).

### 5. `truck_detected` stub processor

`app/services/events/processors/truck_detected_processor.rb`:
```ruby
module Events
  module Processors
    class TruckDetectedProcessor
      def initialize(event:)
        @event = event
      end

      def call
        Rails.logger.info(
          "[Events::Processors::TruckDetectedProcessor] stub ran for event ##{@event.id} " \
          "(device_id=#{@event.device_id.inspect}, payload=#{@event.payload.inspect})"
        )
        # Intentionally a no-op beyond logging — turning this into a started Visit is a
        # separate, later plan. Must not call Visits::CheckInService or create a Visit here.
      end
    end
  end
end
```
`initialize(event:)` + `#call` is the interface every future processor must follow (no shared base
class — matches the `Visits::*Service` plain-PORO convention rather than
`Notifications::Adapters::BaseAdapter`'s `NotImplementedError` convention; revisit once a second
processor exists and shared behavior actually emerges).

### 6. Config / env

`.env.example` — add:
```
# --- Events ingestion (camera / device webhooks) ---
# Shared-secret Bearer token every device POST to /api/events must present via
# `Authorization: Bearer <token>`. Required in production; without it every
# request to /api/events is rejected with 401.
EVENTS_INGEST_TOKEN=
```
No new initializer — token is read directly in `Api::BaseController`, matching the Twilio-adapter
`ENV[...]`-inline pattern rather than the `notifications.rb` `config.x`/`to_prepare` pattern (which
also sidesteps that initializer's documented autoload-path-freezing boot hazard). No
`docker-compose.yml` changes needed.

### 7. Tests

New specs, following this repo's existing structure/conventions:

| File | Covers |
|---|---|
| `spec/models/event_spec.rb` | `define_enum_for(:status)...backed_by_column_of_type(:string)`, presence validations, `for_type` scope |
| `spec/requests/api/events_spec.rb` | 401 no/wrong token; 202 + persisted `pending` `Event` + `have_enqueued_job(Events::ProcessEventJob)` for valid `truck_detected`; 422 + no row for blank `event_type`; 202 + persisted `Event` for an *unrecognized* `event_type` (per the accept-and-fail-async decision) |
| `spec/services/events/ingest_event_service_spec.rb` | mirrors `check_in_service_spec.rb` style — `Event.count` change, `.persisted?`/`.errors`, enqueue assertion |
| `spec/services/events/registry_spec.rb` | `processor_for("truck_detected")` resolves correctly; unknown type raises `Events::UnknownEventTypeError` |
| `spec/services/events/processors/truck_detected_processor_spec.rb` | runs without raising; explicit `expect { }.not_to change(Visit, :count)` — regression guard against the stub silently growing into real logic |
| `spec/jobs/events/process_event_job_spec.rb` | mirrors `send_notification_job_spec.rb` — success → `processed`; processor raises → `failed` + re-raised for retry; unknown type → `failed`, not re-raised |

New factory `spec/factories/events.rb`: `event_type { "truck_detected" }`,
`payload { { plate: "ABC1D23" } }`, `device_id { "gate-cam-01" }`, `received_at { Time.current }`,
traits `:failed`/`:processed`.

Test-env wrinkle: `Api::BaseController` reads `ENV["EVENTS_INGEST_TOKEN"]` directly, so request
specs need a stable known value — add `spec/support/events.rb` setting
`ENV["EVENTS_INGEST_TOKEN"] ||= "test-token"` before the suite runs (parallel to
`spec/support/notifications.rb`), rather than relying on `.env.test`.

No system spec — pure JSON API, request specs already cover it; matches this repo's existing
practice of reserving Capybara/Cuprite for actual browser UI flows.

### Not in this plan (explicitly deferred)

- Wiring `truck_detected` to actually call `Visits::CheckInService`/create a `Visit` — separate plan.
- Idempotency/duplicate-delivery handling (`external_id` column) — explicitly skipped per user decision.
- Avo admin resource for browsing `Event` records — explicitly deferred per user decision.
- `docs/plan.md`/`docs/progress.md` updates — per `CLAUDE.md` convention these get updated as part
  of/after actual implementation, not as part of planning.

## Verification

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/models/event_spec.rb \
  spec/requests/api/events_spec.rb spec/services/events/ spec/jobs/events/
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec   # full suite still green
docker compose run --rm web bin/rubocop
docker compose run --rm web bin/brakeman -q
```
Manual end-to-end against the running dev stack (`docker compose up -d`, `EVENTS_INGEST_TOKEN` set
in `.env`):
```bash
curl -i -X POST http://localhost:3000/api/events \
  -H "Authorization: Bearer $EVENTS_INGEST_TOKEN" -H "Content-Type: application/json" \
  -d '{"event_type":"truck_detected","device_id":"gate-cam-01","data":{"plate":"ABC1D23"}}'
# expect 202 + {"id":...,"status":"pending"}
```
Confirm the `worker` container's Sidekiq log shows `Events::ProcessEventJob` running and the
stub's log line; confirm `Event.find(<id>).status == "processed"` via `bin/rails runner` or
console. Also confirm a request with a wrong/missing token returns 401, and a request with an
unrecognized `event_type` still returns 202 but the `Event` ends up `status: "failed"` after the
job runs.
