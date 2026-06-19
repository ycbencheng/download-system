# AI Prompts & Design Notes

Documentation for the expiring download links take-home: iterative AI collaboration, kept/rejected decisions, and architectural rationale.

## Initial prompt

> Build a Rails app that implements digital product downloads:
> - Merchants define products (name, file, expiry hours, max downloads).
> - A JSON API accepts orders (product + buyer email) and issues a unique expiring download link.
> - Email the buyer a link; enforce expiry and download limits.
> - A simple dashboard shows products, orders, and download activity.
> - Use PostgreSQL, background jobs for email, and document design trade-offs in PROMPTS.md.

**What AI proposed:** Standard Rails CRUD, single-step `GET /d/:token` that streams the file immediately, `increment!` on `download_count`, raw token stored in the database, `request.base_url` for download URLs.

**What I kept:** Rails 8 + PostgreSQL + Solid Queue, JSON order API, email via `deliver_later`, Slim download pages, Svelte dashboard.

**What I rejected:** Single-step download (email scanners burn limits), raw token storage (digest-only), `request.base_url` (Host-header poisoning), `increment!` without a conditional guard (race under concurrent POSTs).

---

## Iteration 1 — Concurrency & limit enforcement

**Prompt:** "How should I enforce max downloads under concurrent POSTs to the same token?"

| AI suggestion | Decision | Rationale |
|---------------|----------|-----------|
| Row-level lock + `increment!` | Rejected | Extra round trips; lock contention under burst traffic |
| Optimistic locking (`lock_version`) | Rejected | Retries add complexity; still two round trips on conflict |
| Single conditional `UPDATE … WHERE download_count < max_downloads` | **Kept** | One atomic statement; see `DownloadsController#download` |

**Inline override:** `app/controllers/downloads_controller.rb` — `update_all` instead of `increment!` so the limit check and increment happen in one SQL statement.

---

## Iteration 2 — Two-step download flow

**Prompt:** "Email link scanners are hitting my download URL and exhausting the limit before the buyer clicks."

| AI suggestion | Decision | Rationale |
|---------------|----------|-----------|
| User-agent blocklist for scanners | Rejected | Fragile, easy to spoof |
| Signed one-time tokens per click | Rejected | Over-engineered for the brief |
| GET landing page (read-only) + POST to consume | **Kept** | Scanners typically issue GET only; buyer clicks POST |

**Inline override:** `config/routes.rb` — separate `GET /d/:token` (show) and `POST /d/:token` (download).

---

## Iteration 3 — Host-safe URL generation

**Prompt:** "Should download URLs in the order API response use `request.base_url`?"

| AI suggestion | Decision | Rationale |
|---------------|----------|-----------|
| `request.base_url` | Rejected | Attacker can spoof `Host` header and poison emailed links |
| `action_mailer.default_url_options` | **Kept** | Configured host; immune to request header manipulation |

**Inline override:** `app/controllers/api/v1/orders_controller.rb` — `download_url_for` uses `default_url_options`, not `request.base_url`.

---

## Iteration 4 — Submission review pass (2026-06-18)

**Prompt:** "Review this repo against the take-home brief and fix trust-breaking gaps before submission."

| Finding | Fix |
|---------|-----|
| README curl uses nested `order` params but controller read flat keys | Accept both shapes in `order_params` |
| CI runs `test:system` but no system tests exist | Add `test/system/order_download_flow_test.rb` |
| README claims `download_count <= max_downloads` CHECK but migration missing | Add DB check constraint + model test |
| Dockerfile Ruby 3.3.7 vs `.ruby-version` 3.4.9 | Align versions; add `npm ci && npm run build` |
| Duplicated `link_status` in concern + dashboard | Extract `DownloadLink#status` / `#status_label` |
| No product creation API | Add `POST /api/v1/products` |
| `RecordNotFound` leaks AR messages | Stable `"Resource not found"` envelope |
| Download button POSTed to GET route | Use `download_confirm_path` |
| Token digest collision unhandled | Retry loop (max 3) on `RecordNotUnique` |

**Kept from security plan:** Host-safe URLs, DownloadEvent rescue (buyer still gets file if audit insert fails), revoke-by-token rake, dashboard-only `allow_browser`, expired+maxed classification precedence, idempotent `revoke!`, CI `npm ci` + `build_js`.

---

## Design Decisions

### Overview

- **Two-step download** — GET `/d/:token` is read-only (landing page). POST `/d/:token` consumes one download. Email scanners and prefetchers typically issue GET only, so they cannot burn the download limit.
- **Atomic limit enforcement** — A single conditional `UPDATE` increments `download_count` only when `download_count < max_downloads`, `expires_at > now`, and `revoked_at IS NULL`. This holds under concurrent POSTs without row-level locks.
- **Token storage** — Raw tokens appear only in the 201 response and the buyer email. The database stores `SHA256(token)` and looks up by digest on a unique index.
- **Snapshot settings** — `expires_at` and `max_downloads` are copied onto each link at creation so later product edits do not affect issued links.

### Data model

- DB constraints enforce invariants that the hot path bypasses: `CHECK (download_count >= 0)`, `CHECK (download_count <= max_downloads)`, positive `expiry_hours`/`max_downloads`, `NOT NULL` + unique `token_digest`, FKs with `on_delete: :restrict` (mirrored by `restrict_with_exception` in models).
- `DownloadEvent` is append-only audit data. `download_count` on the link is the source of truth.
- `buyer_email` uses `URI::MailTo::EMAIL_REGEXP` for format validation.

### Order API (`POST /api/v1/orders`)

- `SecureRandom.urlsafe_base64(32)` for token entropy; retries up to 3 times on digest collision.
- Accepts nested `{ "order": { … } }` (README curl shape) or flat `{ "product_id", "buyer_email" }`.
- Email is enqueued with `deliver_later` after the transaction block commits, so buyers never receive a link to a rolled-back order.
- Errors use a consistent `{ "error": { "code", "message" } }` envelope.

### Product API (`POST /api/v1/products`)

- Minimal create endpoint; no admin UI. Accepts nested or flat params (same pattern as orders).

### Download flow

- Status checks run in order: revoked → expired → limit reached → ready (`DownloadLink#status`).
- GET never changes `download_count`; tests assert the count is unchanged after landing.
- POST uses `update_all` for the increment, then `reload` because Active Record does not refresh the in-memory object after a raw update.
- `revoked_at IS NULL` is part of the UPDATE `WHERE` clause so revocation is enforced atomically with limit and expiry.
- JSON POSTs skip CSRF verification; HTML form POSTs from `button_to` include the token.

### Concurrency testing

- Transactional fixtures are disabled for the parallel POST test so threads can observe each other's commits.
- Connection pool size is raised for the test class; teardown deletes seeded rows manually.

### Revocation

- `DownloadLink#revoke!` sets `revoked_at`. Admin access is via console or `rails download_links:revoke[ID]` — no unauthenticated HTTP endpoint.
- Integration tests revoke an active link mid-flight and assert 410 from both GET and POST.

### Frontend

- The order API and download pages are server-rendered HTML and run without Node installed.
- Vite + Svelte powers the read-only dashboard only. Download pages use a separate layout with no `<script>` tags so token URLs never load JavaScript.
- `vite_dashboard_tags` rescues a missing Vite manifest so the dashboard shell still renders; a server-rendered notice inside `#dashboard` explains when the bundle is absent. The Svelte entrypoint clears that notice on mount.
- `autoBuild` is off in dev/test; `bin/dev` skips the Vite process when `node_modules` is missing.

### Deferred / documented only

- Download idempotency (token replay) — documented approach, not fully implemented.
- Rate limiting on the open order API — documented `Rack::Attack` mitigation, not built.
- Dashboard pagination — feeds are capped at 50/100 rows.
