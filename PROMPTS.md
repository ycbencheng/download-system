# Design Notes

Key architectural decisions for the expiring download links service.

## Overview

- **Two-step download** — GET `/d/:token` is read-only (landing page). POST `/d/:token` consumes one download. Email scanners and prefetchers typically issue GET only, so they cannot burn the download limit.
- **Atomic limit enforcement** — A single conditional `UPDATE` increments `download_count` only when `download_count < max_downloads`, `expires_at > now`, and `revoked_at IS NULL`. This holds under concurrent POSTs without row-level locks.
- **Token storage** — Raw tokens appear only in the 201 response and the buyer email. The database stores `SHA256(token)` and looks up by digest on a unique index.
- **Snapshot settings** — `expires_at` and `max_downloads` are copied onto each link at creation so later product edits do not affect issued links.

## Data model

- DB constraints enforce invariants that the hot path bypasses: `CHECK (download_count >= 0)`, positive `expiry_hours`/`max_downloads`, `NOT NULL` + unique `token_digest`, FKs with `on_delete: :restrict` (mirrored by `restrict_with_exception` in models).
- `DownloadEvent` is append-only audit data. `download_count` on the link is the source of truth.
- `buyer_email` uses `URI::MailTo::EMAIL_REGEXP` for format validation.

## Order API (`POST /api/v1/orders`)

- `SecureRandom.urlsafe_base64(32)` for token entropy.
- Email is enqueued with `deliver_later` after the transaction block commits, so buyers never receive a link to a rolled-back order.
- Errors use a consistent `{ "error": { "code", "message" } }` envelope.

## Download flow

- Status checks run in order: revoked → expired → limit reached → ready.
- GET never changes `download_count`; tests assert the count is unchanged after landing.
- POST uses `update_all` for the increment, then `reload` because Active Record does not refresh the in-memory object after a raw update.
- `revoked_at IS NULL` is part of the UPDATE `WHERE` clause so revocation is enforced atomically with limit and expiry.
- JSON POSTs skip CSRF verification; HTML form POSTs from `button_to` include the token.

## Concurrency testing

- Transactional fixtures are disabled for the parallel POST test so threads can observe each other's commits.
- Connection pool size is raised for the test class; teardown deletes seeded rows manually.

## Revocation

- `DownloadLink#revoke!` sets `revoked_at`. Admin access is via console or `rails download_links:revoke[ID]` — no unauthenticated HTTP endpoint.
- Integration tests revoke an active link mid-flight and assert 410 from both GET and POST.

## Frontend

- The order API and download pages are server-rendered HTML and run without Node installed.
- Vite + Svelte powers the read-only dashboard only. Download pages use a separate layout with no `<script>` tags so token URLs never load JavaScript.
- `vite_dashboard_tags` rescues a missing Vite manifest so the dashboard shell still renders; a server-rendered notice inside `#dashboard` explains when the bundle is absent. The Svelte entrypoint clears that notice on mount.
- `autoBuild` is off in dev/test; `bin/dev` skips the Vite process when `node_modules` is missing.

## Deferred / documented only

- Download idempotency (token replay) — documented approach, not fully implemented.
- Rate limiting on the open order API — documented `Rack::Attack` mitigation, not built.
- Dashboard pagination — feeds are capped at 50/100 rows.
