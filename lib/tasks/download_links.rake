namespace :download_links do
  desc "Revoke a download link by numeric ID or raw token (sets revoked_at, preventing further downloads)"
  task :revoke, [:id_or_token] => :environment do |_t, args|
    id_or_token = args[:id_or_token].to_s
    abort "Usage: rails download_links:revoke[ID_OR_TOKEN]" if id_or_token.blank?

    link = if id_or_token.match?(/\A\d+\z/)
      DownloadLink.find(id_or_token)
    else
      digest = Digest::SHA256.hexdigest(id_or_token)
      DownloadLink.find_by!(token_digest: digest)
    end

    if link.revoked?
      puts "Link ##{link.id} is already revoked (at #{link.revoked_at.iso8601})."
    else
      link.revoke!
      puts "Link ##{link.id} revoked at #{link.revoked_at.iso8601}. Downloads are now blocked."
    end
  end
end
