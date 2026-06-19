# PROMPTS.md

## Purpose

This file documents how I used AI during this take-home.

I used AI to speed up scaffolding, explore concurrency approaches, and draft tests — but I reviewed every meaningful part of the output, changed incorrect or over-abstract parts, and verified behavior myself. I own the final submission. If this shipped, I would own the bugs too.

## What I asked AI to help with

- Scaffolding the Rails app (models, migrations, API controllers, download flow)
- Choosing an approach for concurrent download-limit enforcement
- Designing the two-step GET/POST download flow
- Drafting integration and concurrency tests
- Suggesting a read-only Svelte dashboard structure
- A pre-submission review pass to catch doc/CI/requirement gaps

## Working style

I did not copy AI output blindly.

I used AI for first drafts and trade-off comparisons, then manually reviewed hot-path code (download increment, token handling, URL generation), removed unnecessary abstraction, and added tests around the highest-risk behavior. When AI proposed something I did not trust — `request.base_url`, `increment!` under concurrency, user-agent blocklists — I either rewrote it or rejected it with a simpler alternative.

Inline comments in the code mark the main judgment calls; this file is the running commentary.

---

## Prompt log

### Prompt 1 — Initial build

> Build a Rails app that implements digital product downloads:
>
> - Merchants define products (name, file, expiry hours, max downloads).
> - A JSON API accepts orders (product + buyer email) and issues a unique expiring download link.
> - Email the buyer a link; enforce expiry and download limits.
> - A simple dashboard shows products, orders, and download activity.
> - Use PostgreSQL, background jobs for email, and document design trade-offs in PROMPTS.md.

**Why I used this prompt**

I wanted a first pass on the full flow — data model, order API, download route, and email — so I could focus review time on correctness and concurrency rather than boilerplate.

**What I kept**

- Rails 8 + PostgreSQL + Solid Queue for email delivery
- JSON order API returning a download URL
- `deliver_later` after the order transaction commits
- Slim templates for buyer-facing download pages
- Svelte/TypeScript dashboard (read-only feeds)

**What I changed**

- Replaced single-step download with GET landing + POST consume
- Stored `SHA256(token)` in the database instead of the raw token
- Replaced `increment!` with a single conditional `UPDATE` for limit enforcement
- Built download URLs from `action_mailer.default_url_options`, not `request.base_url`
- Copied `expires_at` and `max_downloads` onto each link at creation (snapshot settings)

**Why I changed it**

The first draft was structurally fine but weak on production edge cases: email scanners burning limits, Host-header poisoning in URLs, race conditions on concurrent POSTs, and unnecessary exposure of raw tokens in the database.

---

### Prompt 2 — Concurrent download limits

> How should I enforce max downloads under concurrent POSTs to the same token?

**Why I used this prompt**

The hot path is a counted, time-limited resource. I needed one approach that stays correct when multiple buyers (or retries) POST at the same time.

**What I kept**

- Single SQL statement that increments only when `download_count < max_downloads`, `expires_at > now`, and `revoked_at IS NULL`
- `revoked_at IS NULL` inside the `WHERE` clause so revocation is enforced atomically with the limit

**What I changed**

- Rejected read-then-`increment!` (extra round trips, races without a conditional WHERE)
- Rejected optimistic locking / `lock_version` (retries, still multi-step)
- Used `update_all` + `reload` instead of Active Record's usual increment helpers

**Why I changed it**

AI's default Rails patterns (`find`, `increment!`) are readable but not safe enough here without additional locking. One conditional `UPDATE` is simpler to reason about and matches what I would ship.

**Inline override:** `app/controllers/downloads_controller.rb` — see comments above `update_all` (Prompt 2).

---

### Prompt 3 — Email scanner / prefetch problem

> Email link scanners are hitting my download URL and exhausting the limit before the buyer clicks.

**Why I used this prompt**

This is a real failure mode for bearer-token download links, not a theoretical concern.

**What I kept**

- Read-only GET landing page that never changes `download_count`
- POST to consume one download when the buyer clicks "Download"

**What I changed**

- Rejected user-agent blocklists (fragile, spoofable)
- Rejected signed one-time sub-tokens per click (over-engineered for the brief)
- Split routes: `GET /d/:token` (show) and `POST /d/:token` (download)

**Why I changed it**

Scanners and prefetchers typically issue GET only. Separating read from consume is a small code change with a large reliability win.

**Inline override:** `config/routes.rb` — `download_landing` vs `download_confirm`.

---

### Prompt 4 — Host-safe download URLs

> Should download URLs in the order API response use `request.base_url`?

**Why I used this prompt**

The 201 response and buyer email both contain the full URL. I wanted to confirm the URL builder was safe against header manipulation.

**What I kept**

- Named route helper (`download_landing_url`) for consistent path generation

**What I changed**

- Rejected `request.base_url`
- Used `Rails.application.config.action_mailer.default_url_options` as the host source
- Added a test that spoofs the `Host` header and asserts the URL still uses the configured host

**Why I changed it**

An attacker can send `Host: evil.com` and poison links in the API response or email if the app trusts the request host.

**Inline override:** `app/controllers/api/v1/orders_controller.rb` — `download_url_for`.

---

### Prompt 5 — Audit events vs buyer experience

> If `DownloadEvent` insert fails after a successful download increment, should the buyer still get the file?

**Why I used this prompt**

AI's first instinct was transactional all-or-nothing: roll back the download if audit logging fails. That protects audit completeness but punishes the buyer for an infrastructure glitch.

**What I kept**

- Append-only `DownloadEvent` rows with IP and user agent
- `download_count` on the link as the canonical limit counter

**What I changed**

- Wrapped event insert in `rescue`; log the error and still deliver the file
- Documented the drift risk in README Known Limitations

**Why I changed it**

The buyer paid for access; the limit is enforced on the link row, not the audit table. A missing event is ops-visible; a failed delivery is a support ticket.

**Inline override:** `app/controllers/downloads_controller.rb` — comments above the `DownloadEvent` `begin/rescue` block.

---

### Prompt 6 — Pre-submission self-review

I did a manual pass against the brief and README before submitting. I was not asking AI to invent features — I was checking whether the repo matched what we claimed.

**What I found and fixed**


| Gap                                                                         | Fix                                               |
| --------------------------------------------------------------------------- | ------------------------------------------------- |
| README curl uses nested `order` params; controller only read flat keys      | `order_params` accepts both shapes                |
| CI runs `test:system` but no system tests existed                           | Added `test/system/order_download_flow_test.rb`   |
| README cited `download_count <= max_downloads` CHECK; migration was missing | Added check constraint + model test               |
| Dockerfile Ruby 3.3.7 vs `.ruby-version` 3.4.9                              | Aligned versions; added `npm ci && npm run build` |
| `link_status` duplicated in concern + dashboard                             | Extracted `DownloadLink#status` / `#status_label` |
| No product creation API (brief requirement)                                 | Added `POST /api/v1/products`                     |
| `RecordNotFound` leaked ActiveRecord messages                               | Stable `"Resource not found"` envelope            |
| Download button POSTed to GET route                                         | `download_confirm_path` in `show.html.slim`       |
| Token digest collision unhandled                                            | Retry loop (max 3) on `RecordNotUnique`           |


**Why this pass mattered**

Working code with broken docs or red CI signals carelessness. These fixes were about reviewer trust, not feature creep.

---

### Prompt 7 — Second-pass realignment (the honest correction)

A later review caught that I had my priorities inverted, and I corrected course.

**What I got wrong the first time**

- I added a **collision retry loop** (max 3 on `RecordNotUnique`) to defend a ~2^-128 SHA-256 digest collision — an event that cannot happen — while the actual bytes were served from `public/downloads/sample.pdf`. The link's expiry, cap, and revocation never protected the file: anyone could fetch `/downloads/sample.pdf` directly. I had hardened the impossible and left the front door open.

**What I changed**

- **Gated the bytes.** Moved the stub to `storage/product_files/` (outside `public/`) and switched the controller to `send_file`. The token is now the only path to the file, so expiry/cap/revocation actually mean something. The file is resolved and verified readable *before* the atomic increment, so a missing file never burns a download.
- **Cut the retry loop.** A 256-bit random token makes a digest collision unreachable; the unique index is correctness insurance, not a hot path. If the impossible happens it surfaces as a 500 rather than hiding a real bug behind a retry. (The retry's `rescue RecordNotUnique` would also have mis-handled the unrelated `order_id` unique violation.)
- **Made the audit abuse-aware.** Added `outcome` to `DownloadEvent` (default `success`) and logged failed attempts — but only against links that exist, never unknown tokens, so the open endpoint cannot become an unbounded write vector.
- **Made prod config honest.** `force_ssl` (tokens are in the URL), the `/up` redirect exclude, and `APP_HOST` over `https`.

**Takeaway**

Breadth is not seniority. The fix that changed the verdict was one boundary (public file → gated stream), not a pile of new features. I deferred real S3 / signed-URL infra, idempotency keys, and a product UI as documented next-steps rather than half-building them.

**Inline override:** `app/controllers/downloads_controller.rb` (`send_file` + pre-increment file check) and `app/controllers/api/v1/orders_controller.rb` (no-retry comment).

---

### Prompt 8 — Hiring-panel review pass

I ran the repo through a hard "senior + VP" review and acted on the findings that were defects rather than features.

**What I changed**

- **Killed the dead destructive migration.** The unique `order_id` index now lives in the original `create_download_links` migration; the later `DELETE … WHERE id NOT IN (MAX(id) GROUP BY order_id)` dedupe migration is gone. In a greenfield repo there were never duplicates to clean up, so keeping destructive no-op SQL was a liability, not "append-only honesty." Verified a from-scratch `db:migrate` reproduces the unique index and matches `schema.rb`.
- **Collapsed the triplicated status→error ladder** into one `ERROR_RESPONSES` map in `DownloadsController`; `show` and the failed-`download` branch both render from it, so a message/status can't drift between copies.
- **Extracted the atomic consume** into `DownloadLink#consume` so the core invariant has a model seam instead of being welded to the controller.
- **Guarded the audit vocabulary.** A failed consume that re-reads as `:ok` (clock-skew edge) is coerced to `:limit_reached`, so we never persist or render an out-of-vocabulary outcome.
- **Dashboard auth fails closed in production** — no `DASHBOARD_TOKEN` means 401, since the feeds carry buyer PII. Still optional in dev/test.
- **Added per-IP `Rack::Attack`** on order create and download confirm (disabled in test), turning the documented abuse vector into a real, if coarse, limit.

**What I deliberately did NOT do**

Idempotency keys, presigned-URL infra, a product-creation UI, pagination, and frontend test tooling — still documented next-steps. The point of the pass was to fix unforced errors and consolidate, not to add breadth.

---

## Important judgment calls I made

- **Gated file delivery** — Bytes live outside `public/` and stream via `send_file`; the token is the only path. File readability is checked before the increment so a missing file never consumes a download.
- **No collision retry** — 256-bit token ⇒ unreachable digest collision; the unique index is a backstop, not a retry hot path. Deliberately surfaces as a 500 instead of masking a bug.
- **Two-step download** — GET never consumes a download; POST does. Stops scanners from burning limits.
- **Digest-only token storage** — Raw token exists only in the 201 response and buyer email; DB stores `SHA256(token)`.
- **Atomic conditional UPDATE** — One SQL statement for limit + expiry + revocation checks under concurrency.
- **Abuse-aware audit** — `DownloadEvent.outcome` records success and failed attempts (expired/limit/revoked) for *existing* links only; unknown tokens are never logged.
- **Audit vs delivery** — Buyer gets the file even if `DownloadEvent` insert fails; `download_count` is canonical.
- **Host-safe URLs** — Configured host, not request host, for links in API responses and email.
- **Snapshot link settings** — `expires_at` and `max_downloads` copied at link creation; later product edits do not affect issued links.
- **Status precedence** — Revoked → expired → limit-reached (`DownloadLink#status`); expired wins when both expiry and cap apply.
- **No unauthenticated revoke HTTP endpoint** — Revocation via console/rake only; dashboard stays read-only.
- **Dashboard JS isolated** — Download pages use a layout with no JavaScript; Svelte is dashboard-only.
- **Dashboard feed caps** — Orders capped at 50 rows, download events at 100; all products returned. Pagination deferred for the brief.

## Where I overrode AI

- AI (and my own first pass) defended an impossible digest collision while the file was public → cut the retry, gated the bytes
- AI suggested `request.base_url` for download URLs → configured `default_url_options` instead
- AI suggested `increment!` without a conditional WHERE → single conditional `update_all`
- AI suggested blocking scanners by user-agent → two-step GET/POST flow
- AI suggested failing the download when audit insert fails → log and continue delivery
- AI stored or suggested storing raw tokens → digest-only with unique index lookup
- AI duplicated status logic in controllers → moved to `DownloadLink#status`
- AI's first refactor passes added layers I did not need → kept interfaces minimal for a take-home

## Verification I did myself

- `bin/rails test` — full suite including API, model, concurrency, rake, and seed tests
- `bin/rails test:system` — order API → landing page → confirm click consumes one download
- Parallel POST concurrency test (`downloads_concurrency_test.rb`) — 10 threads, `max_downloads: 5`, assert exactly 5 succeed and every attempt is audited (5 `success` + 5 `limit_reached`)
- Gated delivery — `send_file` returns 200 + `Content-Disposition: attachment`; a missing file returns 500 without consuming a download
- Failure-outcome audit — POSTs to expired/maxed/revoked links log the matching `outcome`; unknown tokens write nothing
- Nested and flat order param shapes both return 201
- Host-header spoof test on order API — URL uses configured host, not attacker host
- Manual smoke via README curl examples (orders + products)
- `npm run build && npm run check` for dashboard frontend
- Confirmed GET landing does not change `download_count`; POST does

## Known limitations

- **Bearer-token model** — Anyone with the URL can download; two-step flow stops scanners, not sharing.
- **Token in the URL** — Documented, not mitigated: it leaks into logs, history, and `Referer`. Gating blocks unauthorized bytes; it does not stop a leaked token from being replayed until expiry/cap/revoke.
- **Open APIs** — No auth on order/product create. Per-IP `Rack::Attack` throttling is in place; admin auth is still a production add.
- **No idempotency** — Retried order requests create duplicate orders/links.
- **Count vs event drift** — Possible if audit insert fails after increment (documented, logged).
- **Shared stub file** — Every demo product points at one `storage/product_files/sample.pdf`; revocation kills the token, not the (shared) file. Production keys delivery on per-product storage via a short-lived presigned URL.
- **Streaming through Puma** — `send_file` is fine for a stub; large files would block a worker and move to presigned URLs / `X-Sendfile`.
- **Idempotency / rate limiting** — Documented approaches only; not implemented.
- **Dashboard pagination** — Feeds capped at 50 orders / 100 events; see `DashboardController` limits.

See README **Known Limitations** and **Production Considerations** for deploy notes.

---

## Architecture reference (interview discussion)

Short summary of system shape. Details also live in README and inline comments.


| Area              | Choice                                                            |
| ----------------- | ----------------------------------------------------------------- |
| Download flow     | GET `/d/:token` (read-only) → POST `/d/:token` (consume)          |
| File delivery     | Token-gated `send_file` from `storage/product_files/`; file verified before increment; no fallback |
| Limit enforcement | Conditional `UPDATE` on `download_links`                          |
| Token storage     | `SHA256(token)` digest, unique index lookup                       |
| Token collision   | No retry — unreachable at 256 bits; unique index is the backstop  |
| Audit             | `DownloadEvent.outcome` (success + failed attempts on existing links only) |
| Order API         | Nested or flat params; email after commit                        |
| Product API       | `POST /api/v1/products` (no admin UI)                             |
| Dashboard         | Read-only Svelte feeds; separate layout from download pages; orders/events capped |
| Revocation        | `revoke!` / `rails download_links:revoke[id_or_token]`            |
| Abuse limiting    | Per-IP `Rack::Attack` throttle on order create + download confirm (disabled in test) |
| Dashboard auth    | Fails closed in production (`DASHBOARD_TOKEN` required); optional in dev/test |
| Prod hardening    | `force_ssl` + `/up` exclude; `APP_HOST` over `https`             |
| Deferred          | Idempotency keys, presigned URLs, product UI, frontend unit tests, full pagination |


