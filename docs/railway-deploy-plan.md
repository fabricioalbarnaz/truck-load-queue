# Deploy a free Railway test env

> Status: **implemented and verified end-to-end** (Steps 0–6 all done — see Progress table below).
> Live test env: `https://truck-load-queue-production.up.railway.app` (Railway project
> `adequate-analysis`). Written before any of it was executed, then updated in place as each step
> landed — kept as the execution log for this work. Still to do: fold the relevant parts into
> `CLAUDE.md`'s Production section and log the work in `docs/progress.md`, per this repo's
> documentation convention (see `docs/events-plan.md` for the same pattern). This file can be
> deleted or left as historical context once that's done.

## Progress

Executed one step at a time, each as its own PR (per user preference — not batched into a single
commit). Update this table as each step lands so the process can resume cleanly if interrupted
mid-way.

| Step | Description | Status | Notes |
|---|---|---|---|
| 0 | Persist this plan to `docs/` | ✅ Done | `docs/railway-deploy-plan.md`, on `railway-deploy` branch |
| 1 | Fix `bin/*` executable bits | ✅ Done, pushed | Committed as `c656be5` on `railway-deploy`, pushed to origin. Note: a normal `git add`/GUI stage on this Windows checkout re-reads mode from disk (always `644`) and silently reverts this fix — only `git update-index --chmod=+x` immediately followed by a commit sticks. Hit this twice during execution (`9a763e3` accidentally reverted it) before landing correctly. |
| 2 | Decide dashboard-only config (no `railway.toml`) | ✅ Decided (design-only step, nothing to commit) | documented above, no repo change needed |
| 3 | Provision Railway project (Postgres, Redis, web, worker services) | ✅ Done | Project `adequate-analysis`; services `truck-load-queue` (web, public domain `truck-load-queue-production.up.railway.app`), `spirited-dream` (worker), `Postgres`, `Redis`, all Online. Web log confirms clean boot, no `bin/rails` permission error. Worker log confirms Sidekiq connected to `redis.railway.internal` with no errors. Railway CLI installed locally (`~/.railway/bin/railway.exe`, on PATH) and linked to this project for log access. |
| 4 | Confirm seeding worked | ✅ Done | Web deploy log: `Seeded 4 roles and admin user (admin@test.com)`. `GET /up` → `HTTP 200`. |
| 5 | Run end-to-end verification checklist | ✅ Done | User ran all 5 steps manually against `truck-load-queue-production.up.railway.app`: sign-in, check-in, issue order, finish loading, and the public `/public/queue` screen updating live in a second tab — all worked. Confirms `REDIS_URL` is correctly wired for both Sidekiq and Action Cable. |
| 6 | Document manual redeploy workflow | ✅ Done (docs-only) | no execution needed until a first deploy exists to redeploy |

### Post-merge: the `bin/*` fix got lost a third time, and the deploy branch changed

`railway-deploy`'s PR (#12) was **squash-merged** into `main` — its single-commit diff only
included the docs changes, not the `bin/*` mode fix, even though the pushed branch tip genuinely
had it correct (confirmed via `git diff`). Almost certainly the same Windows/NTFS issue biting
again, this time via whatever tool performed the squash locally. Refixed directly on `main`
(commit `ec8b8ae`). GitHub also auto-deleted `railway-deploy` after the merge, which broke
Railway's auto-deploy trigger (both services were still watching that branch). Resolved by
pushing a new `test` branch (from `main`, with the fix included) and repointing both Railway
services' Settings → Source → Branch to `test` — confirmed redeployed cleanly from commit
`ec8b8ae`, healthcheck `200`, no `permission denied`, Sidekiq connected to Redis with no errors.

Also set `git config core.fileMode false` locally (this machine only, not committed) — git no
longer compares the working tree's file mode against the index at all, which eliminates the
permanent cosmetic `M` noise `bin/*` produced in `git status`/`git diff` on this Windows checkout.
Side effect worth remembering: any *future* permission change on this machine still needs the
explicit `git update-index --chmod=+x <file>` + immediate-commit sequence — git will no longer
auto-detect a chmod from the filesystem at all, for any file, not just `bin/*`.

**Current deploy source of truth: branch `test`**, not `railway-deploy` (deleted) or `main`
(Railway isn't watching it). Keep this in mind for future updates — see Step 6 above for the
redeploy workflow, applied to whichever branch Railway is actually configured to watch at the
time.

## Context

The user wants a live, publicly reachable test/staging deployment of this app (currently only ever
run locally via Docker Compose or a one-off local production smoke test — see `docs/progress.md`
Phase 10) so they can demo/verify it without their own machine running. Researched free hosting
options for a Dockerized Rails 8 app needing Postgres + Redis + a web process + a separate Sidekiq
worker process; **Railway** is the only option that runs all four pieces natively from the existing
`Dockerfile` with no code changes to the app's architecture, no card required to start, via a
one-time $5 usage credit. User confirmed this choice over Render/Cloud Run alternatives.

Goal: get `main` (or this `events` branch, user's choice at execution time) live on Railway,
reachable in a browser, with working sign-in → check-in → dispatch → queue → public-screen flows.
This is an explicitly throwaway test env, not a production deploy — the plan optimizes for "works
end-to-end soon" over long-term operability.

## Blocking repo bug found during planning

`git ls-files -s bin/` (verified directly) shows every `bin/*` script — `bin/rails`,
`bin/docker-entrypoint`, `bin/rake`, etc. — committed as mode `100644` (non-executable), not
`100755`. `docs/progress.md`'s Phase 10 log already flagged this exact problem locally (`docker
compose up` failed with `exec: "./bin/rails": permission denied` until `chmod +x bin/*` was run
in the working tree) but the fix was never committed. Railway builds the image straight from what
git has via the Dockerfile's `COPY . .` (confirmed: `Dockerfile` line 43), using git's stored file
mode — so the same permission error will hit the very first Railway build (`ENTRYPOINT
["/rails/bin/docker-entrypoint"]`, `Dockerfile` line 68, and `CMD ["./bin/rails", "server"]`, line
74) unless fixed first. This must be a real commit, not a Railway-side workaround.

## Step 1 — Fix `bin/*` executable bits (commit required)

```bash
git update-index --chmod=+x bin/rails bin/rake bin/setup bin/dev bin/rubocop bin/brakeman bin/importmap bin/docker-entrypoint
git commit -m "Fix executable bit on bin/* scripts (was lost, blocks Docker builds)"
```
Verify: `git ls-files -s bin/` — every entry should read `100755` afterward. Push before starting
the Railway build in Step 3.

## Step 2 — No `railway.toml`; configure via Railway's dashboard

Considered adding a `railway.toml` for `healthcheckPath`/`startCommand`, but a repo-root config
file's `startCommand` applies to every service built from that repo — a real conflict since the
web and worker services need *different* start commands from the same Dockerfile. Railway's own
documented pattern for this exact "web + worker from one repo" shape is two services, each with
its own **Custom Start Command** set individually in the dashboard (Settings → Deploy tab) — no
shared-file conflict, trivially inspectable/reversible for a throwaway env. `healthcheckPath` is
likewise a one-field per-service dashboard setting. Skip config-as-code entirely for this pass.

Key mechanic this relies on: `bin/docker-entrypoint` (confirmed, read directly) only runs
`./bin/rails db:prepare` when the exact trailing container command is `./bin/rails server` (line
10: `if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]`). Leaving the **web**
service's Start Command blank keeps the Dockerfile's baked-in `ENTRYPOINT`+`CMD` intact, so this
condition is true and migrations/seeds run. Setting the **worker** service's Start Command to
`bundle exec sidekiq` makes Railway override the `ENTRYPOINT` in exec form entirely (confirmed
against Railway's docs) — the worker skips `bin/docker-entrypoint` altogether, so it never runs
`db:prepare` (no double-migration/reseed risk), at the minor/irrelevant cost of also skipping the
entrypoint's jemalloc `LD_PRELOAD` line for that process.

## Step 3 — Provisioning order

1. Push the Step 1 commit.
2. Railway: new project, connect to the GitHub repo/branch. Dockerfile auto-detected, no config
   file needed.
3. Add the **Postgres** plugin ("+ New" → Database → PostgreSQL). Leave Public Networking **off**.
4. Add the **Redis** plugin the same way. Leave Public Networking **off**.
5. **Web service** (the one Railway creates from the repo):
   - Start Command: leave blank/default.
   - Healthcheck Path: `/up` (matches `config/routes.rb`'s `get "up" => "rails/health#show"` and
     the Dockerfile's own baked-in `HEALTHCHECK`; `config/environments/production.rb` already
     excludes `/up` from the `force_ssl` HTTPS redirect, and `config.hosts` is unset/unrestricted,
     so Railway's `*.up.railway.app` domain needs no code change).
   - Variables (see table below).
   - Networking: generate a public domain.
6. **Worker service**: "+ New" → GitHub Repo → same repo/branch (second, independent service).
   - Start Command: `bundle exec sidekiq`.
   - Healthcheck Path: leave blank (it never binds a port — setting one would make every deploy
     hang waiting for an HTTP response that never comes).
   - Networking: no public domain needed.
   - Variables (see table below).
7. Deploy web first; watch logs for the build completing without a `bin/rails: permission denied`
   (confirms Step 1), then `bin/docker-entrypoint`'s `db:prepare` migration output and no
   `ActiveSupport::MessageEncryptor::InvalidMessage` (confirms `RAILS_MASTER_KEY` is correct), then
   the healthcheck going green.
8. Deploy worker; logs should show Sidekiq's boot banner with **no** migration output (expected —
   see the ENTRYPOINT-bypass mechanic above, not a bug).

### Environment variables

Both services live in the same Railway project so `${{Postgres.*}}`/`${{Redis.*}}` variable
references resolve. Don't set `RAILS_ENV` (baked into the Dockerfile already) or `PORT` (Railway
injects it; `config/puma.rb` already reads `ENV.fetch("PORT", 3000)`).

**Web:**
| Variable | Value | Why |
|---|---|---|
| `RAILS_MASTER_KEY` | contents of local `config/master.key` | Decrypts `config/credentials.yml.enc`, including the `active_record_encryption` keys `Driver#cpf`/`Driver#phone` need. Wrong value = boot fails immediately. |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | `config/database.yml`'s production block merges `DATABASE_URL` on top of its `username`/`password` fields — this alone is sufficient, don't also set `APP_DATABASE_PASSWORD`. |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Feeds `config/cable.yml`'s production `redis` adapter (Action Cable) and Sidekiq's default connection resolution. |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | your choice | Seed admin login (`db/seeds.rb`); falls back to `admin@example.com`/`changeme123` if unset. |
| `EVENTS_INGEST_TOKEN` | random string (e.g. `openssl rand -hex 32`) | Only gates `/api/events`; harmless to set even if unused, otherwise that one endpoint just 401s forever. |
| `TWILIO_ACCOUNT_SID`/`TWILIO_AUTH_TOKEN`/`TWILIO_SMS_FROM`/`TWILIO_WHATSAPP_FROM` | leave unset, or real/trial values | See gotcha below — deliberate decision, not an oversight. |

**Worker:** `RAILS_MASTER_KEY`, `DATABASE_URL`, `REDIS_URL` (same values as web), and the same
`TWILIO_*` decision as web (must match — the actual Twilio API call happens in this process, via
`SendNotificationJob`). Do **not** set `EVENTS_INGEST_TOKEN`/`ADMIN_EMAIL`/`ADMIN_PASSWORD` here —
irrelevant to a process that never serves HTTP or seeds.

## Step 4 — Confirm seeding worked

`db:prepare` runs only on the web service (by construction, per the mechanic above) and is safe to
re-run on redeploys (idempotent `find_or_create_by!` in `db/seeds.rb`, and only reseeds a freshly
created DB). Confirm via the deploy log line `Seeded 4 roles and admin user (...)`, or just sign in
at `https://<app>.up.railway.app/users/sign_in` with the admin credentials — success proves DB
connectivity, migrations, and seeding all worked.

## Step 5 — End-to-end verification checklist

1. Sign in as admin.
2. Check in a driver+truck at `/registration/visits`. If this throws `Missing Active Record
   encryption credential: deterministic_key`, `RAILS_MASTER_KEY` doesn't match the committed
   `config/credentials.yml.enc` — re-copy it exactly from local `config/master.key`.
3. Issue an order at `/expedition/visits` (`PATCH issue_order`) — should return normally regardless
   of Twilio config, since notification sending is async via Sidekiq, decoupled from the request.
4. Finish loading at `/queue/visits` (`PATCH finish`).
5. Open `/public/queue` in a second, unauthenticated tab; repeat step 3 or 4 in the first tab and
   confirm the second tab updates live without a refresh. This is the step most likely to fail
   silently if `REDIS_URL` is wrong on the web service (HTTP actions still return 200; only the
   broadcast is affected). Check: DevTools → Network → WS filter for a `cable` connection at `101
   Switching Protocols`; if connected but not updating, check web service logs for
   `Redis::CannotConnectError`/`Redis::ConnectionError` at the moment of the action. A clean Sidekiq
   boot on the worker (no Redis errors) is a strong signal the same `REDIS_URL` value is also good
   for Action Cable.

## Step 6 — Updating the test env with new commits (manual redeploy workflow)

Once the two services exist (Step 3), pushing new code doesn't automatically go live unless
Railway's auto-deploy is left on — and for a hand-driven test env, explicit manual control over
*when* a redeploy happens is more useful than auto-deploy-on-push (avoids a half-finished local
commit going live mid-edit). Two ways to update, pick one as the working pattern:

**Option A — manual redeploy from the dashboard (simplest, no local tooling):**
1. Turn off auto-deploy on both services: each service → Settings → Source → toggle "Auto Deploy"
   off. They'll stay pinned to whatever was last deployed until told otherwise.
2. Make code changes locally, commit, push to the branch Railway is watching (`main` or `events`,
   per Step 3.2's choice).
3. In the Railway dashboard, open the **web** service → Deployments tab → "Deploy" (or "Redeploy")
   → picks up the new commit, rebuilds the image, reruns `bin/docker-entrypoint`'s `db:prepare`
   (so any new migration in the push gets applied automatically — no separate migrate step).
4. Redeploy the **worker** service the same way, so it's running code from the same commit as web
   (a version-mismatched worker would still work most of the time since both just call into the
   same `Event`/`Visit`/job classes, but keep them in lockstep to avoid confusing debugging later).
5. Watch each service's deploy logs the same way as the first deploy (Step 3.7/3.8) — build
   succeeds, `db:prepare` output on web only, healthcheck green — before considering the update
   live.

**Option B — Railway CLI (`railway up`), for faster local iteration:**
1. `railway login`, then `railway link` once per local clone to associate this repo with the
   existing Railway project.
2. After local changes, `railway up --service web` (and separately `--service worker`) builds and
   deploys directly from the local working tree via the CLI, without needing a git push first —
   useful for testing an uncommitted change before it's worth a commit, but means the deployed
   code and git history can drift; make sure to still commit/push once the change is confirmed
   good, so `docs/progress.md` and the repo stay the source of truth.
3. Same log-watching verification as Option A applies after each `railway up`.

Either way, re-run the Step 5 checklist (or just the specific flow the new feature touches) after
each redeploy — a green build/healthcheck only confirms the app booted, not that the feature being
tested actually works.

## Known limitation: Twilio notifications will fail unless real credentials are set

`config/initializers/notifications.rb` (read directly, confirmed) picks the adapter purely on
`Rails.env.production?` — `nil` (→ real `TwilioSmsAdapter`/`TwilioWhatsappAdapter`) in production,
`TestAdapter` everywhere else. Since Railway runs the production image, it's always the real Twilio
path — there's no staging-specific flag to fall back to `TestAdapter`, and changing that is out of
scope for this deploy. Concretely: if `TWILIO_*` is unset, checking in/issuing orders/finishing
loads all still work and return normal responses (notification enqueue is fully decoupled via
Sidekiq); only the async `SendNotificationJob` fails when the worker picks it up, retries 5x with
polynomial backoff, then dies — visible only in worker logs, never blocks the UI. Two explicit
options: (a) leave `TWILIO_*` unset — zero cost, fine if the goal is just the workflow, expect
cosmetic failed-job noise in worker logs; (b) set up a free Twilio trial and put matching real
credentials on **both** services if verifying actual SMS/WhatsApp delivery matters (note Twilio
trial accounts can typically only send to phone numbers verified in the Twilio console).

## Cost / lifespan expectations

Railway's Trial plan: no card required, one-time $5 credit, consumed by actual per-second
usage across all 4 services, expires 30 days after signup or when exhausted (whichever first);
project volume data is held ~30 more days after that before deletion. For this app's low-traffic
footprint, expect roughly 1–3 weeks of continuous 24/7 running (can't pin an exact figure — Railway
per-unit rates shift across pricing revisions, verify current numbers at railway.com/pricing before
committing to a date). To stretch it: manually stop all 4 services from the dashboard between test
sessions rather than leaving them running 24/7 — usage is billed by actual time, not a flat
reservation. When it runs out: given this is explicitly a throwaway test env, default to
decommissioning rather than adding a card, unless the user says otherwise at that point.

## Verification of this plan itself

- `git ls-files -s bin/` before/after Step 1 to confirm the executable-bit fix took.
- Railway deploy logs for both services, watched live during first deploy, checked against the
  specific log lines called out in Step 3/Step 4 above.
- The 5-step manual browser checklist in Step 5, run against the live Railway URL.

## Current status

See the **Progress** table near the top of this file — kept up to date as each step lands, so this
doubles as the execution log until the work is finished and folded into `docs/progress.md` per the
note at the very top of this file.
