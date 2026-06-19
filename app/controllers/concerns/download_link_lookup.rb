module DownloadLinkLookup
  extend ActiveSupport::Concern

  private

  def find_link_by_token(token)
    digest = Digest::SHA256.hexdigest(token.to_s)
    DownloadLink.includes(order: :product).find_by(token_digest: digest)
  end
end
