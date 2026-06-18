module DownloadLinkLookup
  extend ActiveSupport::Concern

  private

  def find_link_by_token(token)
    digest = Digest::SHA256.hexdigest(token.to_s)
    DownloadLink.includes(order: :product).find_by(token_digest: digest)
  end

  def link_status(link)
    return :revoked if link.revoked?
    return :expired if link.expires_at <= Time.current
    return :limit_reached if link.download_count >= link.max_downloads

    :ok
  end
end
