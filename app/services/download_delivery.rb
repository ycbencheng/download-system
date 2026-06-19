# Resolves the on-disk path for a product's file.
#
# Take-home: files live under storage/product_files/ (NOT public/), so the only
# route to the bytes is through DownloadsController, which authorizes the token
# before streaming. There is deliberately NO fallback file — a product pointing
# at a missing file is a misconfiguration we surface (and never consume a
# download for), not one we mask by silently serving the wrong bytes.
#
# Production: this would mint a short-lived (30–60s) presigned S3/GCS URL so the
# web server, not a Puma worker, ships large files. See README
# "What would change for production".
class DownloadDelivery
  ROOT = Rails.root.join("storage", "product_files")

  # Absolute Pathname to a readable file, or nil if the product has no file or
  # the file is missing/unreadable. File.basename strips any path so file_name
  # cannot traverse outside ROOT.
  def self.path_for(product)
    return if product.file_name.blank?

    path = ROOT.join(File.basename(product.file_name.to_s))
    return unless path.file? && path.readable?

    path
  end
end
