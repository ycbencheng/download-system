# Resolves the public path for a product download.
# Take-home stub: serves files from public/downloads/ when present, else sample.pdf.
# Production would return a short-lived presigned URL keyed on product storage (file_name).
class DownloadDelivery
  FALLBACK_PATH = "/downloads/sample.pdf"

  def self.path_for(product)
    return FALLBACK_PATH if product.file_name.blank?

    candidate = product.file_name.to_s.delete_prefix("/")
    public_file = Rails.public_path.join("downloads", candidate)
    return "/downloads/#{candidate}" if public_file.file?

    FALLBACK_PATH
  end
end
