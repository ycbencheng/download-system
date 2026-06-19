# Demo-ready data for local development and reviewer walkthroughs.
#
# Seeds are idempotent: keyed by stable, unique columns so re-running them
# does not duplicate rows. The four download links below are deliberately
# wired to cover every state in the error matrix so a reviewer can paste
# each URL into a browser and see the matching response without needing to
# manipulate clocks or counters.
#
# The DB stores only SHA256(token); the raw tokens below appear only here
# and in the URLs printed at the end of this file (and, in production, in
# the buyer's email).
#
#   normal   -> http://localhost:3000/d/dev-active-link-token   (200, Download button)
#   expired  -> http://localhost:3000/d/dev-expired-link-token  (410 expired)
#   maxed    -> http://localhost:3000/d/dev-maxed-link-token    (403 limit reached)
#   revoked  -> http://localhost:3000/d/dev-revoked-link-token  (410 revoked)
#
# Clicking the Download button on the normal link redirects to the real
# placeholder at public/downloads/sample.pdf.

require "digest"

def seed_token_digest(raw_token)
  Digest::SHA256.hexdigest(raw_token)
end

def seed_download_link!(order:, raw_token:, **attrs)
  link = DownloadLink.find_or_initialize_by(order: order)
  link.token_digest = seed_token_digest(raw_token)
  attrs.each { |key, value| link.public_send("#{key}=", value) }
  link.save!
  link
end

ebook = Product.find_or_create_by!(name: "Sample Ebook") do |product|
  product.file_name = "ebook.pdf"
  product.expiry_hours = 24
  product.max_downloads = 3
end

course = Product.find_or_create_by!(name: "Intro Course") do |product|
  product.file_name = "course.zip"
  product.expiry_hours = 72
  product.max_downloads = 5
end

# Orders are keyed by (product, buyer_email) so the seed is idempotent
# without depending on insertion order or auto-increment IDs.
alice_order   = Order.find_or_create_by!(product: ebook,  buyer_email: "alice@example.com")
bob_order     = Order.find_or_create_by!(product: course, buyer_email: "bob@example.com")
carol_order   = Order.find_or_create_by!(product: ebook,  buyer_email: "carol@example.com")
dave_order    = Order.find_or_create_by!(product: course, buyer_email: "dave@example.com")

active_link = seed_download_link!(
  order: alice_order,
  raw_token: "dev-active-link-token",
  expires_at: 24.hours.from_now,
  max_downloads: ebook.max_downloads,
  download_count: 0
)

# Pre-expired link: expires_at in the past. Snapshot max_downloads from the
# product at creation time (mirrors what the order API does).
seed_download_link!(
  order: bob_order,
  raw_token: "dev-expired-link-token",
  expires_at: 1.hour.ago,
  max_downloads: course.max_downloads,
  download_count: 0
)

# Pre-maxed link: download_count == max_downloads, still within the expiry
# window so the failure is unambiguously "limit reached", not "expired".
seed_download_link!(
  order: carol_order,
  raw_token: "dev-maxed-link-token",
  expires_at: 24.hours.from_now,
  max_downloads: ebook.max_downloads,
  download_count: ebook.max_downloads
)

# Revoked link: valid window + count, but revoked_at is stamped. Proves the
# revocation kill switch wins over an otherwise-usable link.
seed_download_link!(
  order: dave_order,
  raw_token: "dev-revoked-link-token",
  expires_at: 24.hours.from_now,
  max_downloads: course.max_downloads,
  download_count: 0,
  revoked_at: 1.hour.ago
)

# One historical DownloadEvent on the active link so the dashboard feed has
# something non-empty to render on first boot.
DownloadEvent.find_or_create_by!(
  download_link: active_link,
  ip: "127.0.0.1",
  user_agent: "curl/8.0"
) do |event|
  event.created_at = 1.hour.ago
end

puts "Seeded #{Product.count} products, #{Order.count} orders, " \
     "#{DownloadLink.count} download links, #{DownloadEvent.count} download events."
puts
puts "Try these URLs (raw tokens; DB stores only SHA256):"
puts "  normal   http://localhost:3000/d/dev-active-link-token   -> 200 + Download button"
puts "  expired  http://localhost:3000/d/dev-expired-link-token  -> 410 expired"
puts "  maxed    http://localhost:3000/d/dev-maxed-link-token    -> 403 limit reached"
puts "  revoked  http://localhost:3000/d/dev-revoked-link-token  -> 410 revoked"
