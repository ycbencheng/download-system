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

- Rejected row-level locks + `increment!` (extra round trips, contention)
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

- Wrapped event insert in `rescue`; log the error and still redirect to the file
- Documented the drift risk in README Known Limitations

**Why I changed it**

The buyer paid for access; the limit is enforced on the link row, not the audit table. A missing event is ops-visible; a failed redirect is a support ticket.

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

## Important judgment calls I made

- **Two-step download** — GET never consumes a download; POST does. Stops scanners from burning limits.
- **Digest-only token storage** — Raw token exists only in the 201 response and buyer email; DB stores `SHA256(token)`.
- **Atomic conditional UPDATE** — One SQL statement for limit + expiry + revocation checks under concurrency.
- **Audit vs delivery** — Buyer gets the file even if `DownloadEvent` insert fails; `download_count` is canonical.
- **Host-safe URLs** — Configured host, not request host, for links in API responses and email.
- **Snapshot link settings** — `expires_at` and `max_downloads` copied at link creation; later product edits do not affect issued links.
- **Status precedence** — Revoked → expired → limit-reached (`DownloadLink#status`); expired wins when both expiry and cap apply.
- **No unauthenticated revoke HTTP endpoint** — Revocation via console/rake only; dashboard stays read-only.
- **Dashboard JS isolated** — Download pages use a layout with no JavaScript; Svelte is dashboard-only.
- **Dashboard feed caps** — Orders capped at 50 rows, download events at 100; all products returned. Pagination deferred for the brief.

## Where I overrode AI

- AI suggested `request.base_url` for download URLs → configured `default_url_options` instead
- AI suggested `increment!` / row locks for limits → single conditional `update_all`
- AI suggested blocking scanners by user-agent → two-step GET/POST flow
- AI suggested failing the download when audit insert fails → log and continue redirect
- AI stored or suggested storing raw tokens → digest-only with unique index lookup
- AI duplicated status logic in controllers → moved to `DownloadLink#status`
- AI's first refactor passes added layers I did not need → kept interfaces minimal for a take-home

## Verification I did myself

- `bin/rails test` — full suite including API, model, concurrency, rake, and seed tests
- `bin/rails test:system` — order API → landing page → download redirect flow
- Parallel POST concurrency test (`downloads_concurrency_test.rb`) — 10 threads, `max_downloads: 5`, assert exactly 5 succeed
- Nested and flat order param shapes both return 201
- Host-header spoof test on order API — URL us***Inline***es configured host, not attacker host
- Token digest collision retry — simulates `RecordNotUnique` on first save, asserts retry succeeds
- Manual smoke via README curl examples (orders + products)
- `npm run build && npm run check` for dashboard frontend
- Confirmed GET landing does not change `download_count`; POST does

## Known limitations

- **Bearer-token model** — Anyone with the URL can download; two-step flow stops scanners, not sharing.
- **Open APIs** — No auth on order/product create; production would add throttling and admin auth.
- **No idempotency** — Retried order requests create duplicate orders/links.
- **Count vs event drift** — Possible if audit insert fails after increment (documented, logged).
- **Placeholder file serving** — `public/downloads/sample.pdf` is not revocation-aware; production would use presigned URLs.
- **Idempotency / rate limiting** — Documented approaches only; not fully implemented.
- **Dashboard pagination** — Feeds capped at 50 orders / 100 events; see `DashboardController` limits.

See README **Known Limitations** and **Production Considerations** for deploy notes.

---

## Architecture reference (interview discussion)

Short summary of system shape. Details also live in README and inline comments.


| Area              | Choice                                                            |
| ----------------- | ----------------------------------------------------------------- |
| Download flow     | GET `/d/:token` (read-only) → POST `/d/:token` (consume)          |
| Limit enforcement | Conditional `UPDATE` on `download_links`                          |
| Token storage     | `SHA256(token)` digest, unique index lookup                       |
| Order API         | Nested or flat params; email after commit; digest collision retry |
| Product API       | `POST /api/v1/products` (no admin UI)                             |
| Dashboard         | Read-only Svelte feeds; separate layout from download pages; orders/events capped |
| Revocation        | `revoke!` / `rails download_links:revoke[id_or_token]`            |
| Deferred          | Idempotency keys, `Rack::Attack`, download token replay, full pagination           |


