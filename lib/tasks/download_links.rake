namespace :download_links do
  desc "Revoke a download link by ID (sets revoked_at, preventing further downloads)"
  task :revoke, [:id] => :environment do |_t, args|
    abort "Usage: rails download_links:revoke[ID]" if args[:id].blank?

    link = DownloadLink.find(args[:id])

    if link.revoked?
      puts "Link ##{link.id} is already revoked (at #{link.revoked_at.iso8601})."
    else
      link.revoke!
      puts "Link ##{link.id} revoked at #{link.revoked_at.iso8601}. Downloads are now blocked."
    end
  end
end
