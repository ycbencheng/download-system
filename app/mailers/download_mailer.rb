class DownloadMailer < ApplicationMailer
  def link_email(order, download_url)
    @order = order
    @download_url = download_url
    @product = order.product

    mail(
      to: order.buyer_email,
      subject: "Your download link for #{@product.name}"
    )
  end
end
