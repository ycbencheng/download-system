# Throttle abuse on the open write + download endpoints. The order API queues an
# email to an arbitrary address and the download-confirm endpoint is unauthenticated,
# so both are spam/cost vectors without a limit. Limits are generous enough not to
# block a real buyer retrying; production would tune them and likely key on more
# than IP. Disabled in test so integration/concurrency specs aren't rate-limited.
Rack::Attack.enabled = !Rails.env.test?

class Rack::Attack
  throttle("orders/ip", limit: 20, period: 60) do |req|
    req.ip if req.post? && req.path == "/api/v1/orders"
  end

  throttle("downloads/ip", limit: 60, period: 60) do |req|
    req.ip if req.post? && req.path.start_with?("/d/")
  end

  self.throttled_responder = lambda do |_request|
    body = { error: { code: "rate_limited", message: "Too many requests. Please retry shortly." } }
    [ 429, { "Content-Type" => "application/json" }, [ body.to_json ] ]
  end
end
