class AddDownloadCountUpperBoundCheck < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :download_links,
      "download_count <= max_downloads",
      name: "download_links_count_within_max"
  end
end
