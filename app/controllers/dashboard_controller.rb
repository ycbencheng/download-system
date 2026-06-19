class DashboardController < ApplicationController
  # Dashboard only — buyer download pages must work on older browsers (email links).
  allow_browser versions: :modern

  layout "dashboard"

  def index
  end
end
