module ApplicationHelper
  def vite_dashboard_tags
    safe_join([ vite_client_tag, vite_javascript_tag("application") ].compact)
  rescue ViteRuby::MissingEntrypointError => e
    Rails.logger.warn("[vite] dashboard bundle unavailable: #{e.message}")
    "".html_safe
  end
end
