class SitemapController < ApplicationController
  def show
    @static_urls = [
      { url: root_url, priority: "1.0" },
      { url: documents_url, priority: "0.8" },
      { url: geography_url, priority: "0.6" },
      { url: insights_url, priority: "0.6" }
    ]
    @documents = Document.select(:dok_id, :updated_at).order(:dok_id)

    expires_in 1.hour, public: true
    render layout: false
  end
end
