xml.instruct! :xml, version: "1.0"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @static_urls.each do |entry|
    xml.url do
      xml.loc entry[:url]
      xml.priority entry[:priority]
    end
  end

  @documents.each do |document|
    xml.url do
      xml.loc document_url(document.dok_id)
      xml.lastmod document.updated_at.strftime("%Y-%m-%d") if document.updated_at
      xml.priority "0.5"
    end
  end
end
