# Resolves the on-disk path for a product's file. Files live outside public/ so
# the only route to the bytes is the token-gated controller. There is no fallback
# file: a missing file returns nil so the caller fails loudly rather than serving
# the wrong bytes. (Production swaps this for a presigned URL — see README.)
class DownloadDelivery
  ROOT = Rails.root.join("storage", "product_files")

  # Absolute Pathname to a readable file, or nil. File.basename strips any path
  # so file_name cannot traverse outside ROOT.
  def self.path_for(product)
    return if product.file_name.blank?

    path = ROOT.join(File.basename(product.file_name.to_s))
    return unless path.file? && path.readable?

    path
  end
end
