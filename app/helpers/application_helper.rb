module ApplicationHelper
  # Vite tags load on the dashboard layout only. Download pages use a separate
  # layout with no scripts. Rescuing MissingEntrypointError lets the dashboard
  # shell render without a built bundle; the view shows a notice until Svelte mounts.
  def vite_dashboard_tags
    safe_join([ vite_client_tag, vite_javascript_tag("application") ].compact)
  rescue ViteRuby::MissingEntrypointError => e
    Rails.logger.warn("[vite] dashboard bundle unavailable, rendering no-JS fallback: #{e.message}")
    "".html_safe
  end
end
