# Manual QA Checklist

Run with `bin/dev` and Postgres up.

## Health and seeds

- [ ] `GET /up` returns 200
- [ ] `bin/rails db:seed` prints four demo URLs
- [ ] `/d/dev-expired-link-token` → 410 expired
- [ ] `/d/dev-maxed-link-token` → 403 limit reached
- [ ] `/d/dev-revoked-link-token` → 410 revoked
- [ ] `/d/bogus` → 404

## Order API

- [ ] `POST /api/v1/orders` → 201 with `download_url`
- [ ] Missing product → 404
- [ ] Invalid email → 422
- [ ] Letter Opener shows email with the same URL

## Active download

- [ ] Reset `download_count` on dev active link if needed
- [ ] `GET /d/dev-active-link-token` → 200 landing, no `<script>` tags
- [ ] `POST` (Download button) → 200 file stream with `Content-Disposition: attachment`
- [ ] `storage/product_files/sample.pdf` exists on disk; the file is NOT reachable at `/downloads/sample.pdf`
- [ ] Download Activity shows the success row; failed attempts (expired/maxed/revoked links) show their outcome

## Revocation

- [ ] `bin/rails 'download_links:revoke[dev-revoked-link-token]'` → already revoked message on re-run

## Dashboard

- [ ] `GET /` renders dashboard (or fallback if frontend not built)
- [ ] With `DASHBOARD_TOKEN` set, `/api/v1/products` requires `Authorization: Bearer <token>`

## Automated suite

- [ ] `bin/rails test`
- [ ] `bin/rails test:system`
- [ ] `npm run build && npm run check` (optional, needs Node)
