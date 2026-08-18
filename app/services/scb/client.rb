module Scb
  # Thin wrapper around Statistics Sweden's PxWeb API. No API key needed,
  # but it's rate-limited (30 requests/10s, 150,000 cells/query) — callers
  # should cache, not query live per chat message.
  class Client
    BASE_URL = "https://api.scb.se/OV0104/v1/doris/en/ssd"

    class Error < StandardError; end

    def initialize
      @connection = Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 1, backoff_factor: 2,
                          retry_statuses: [ 429, 500, 502, 503 ]
        f.adapter Faraday.default_adapter
      end
    end

    # table_path: e.g. "/AM/AM0401/AM0401L/NAKUArblheltidstudAr"
    # query_body: PxWeb query language hash, e.g. { query: [...], response: { format: "json" } }
    def query(table_path, query_body)
      # A leading "/" makes Faraday treat this as root-relative, dropping
      # the /OV0104/v1/doris/en/ssd prefix from BASE_URL entirely — strip it.
      response = @connection.post(table_path.delete_prefix("/")) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = query_body.to_json
      end

      unless response.success?
        raise Error, "SCB API error #{response.status}: #{response.body}"
      end

      JSON.parse(response.body.force_encoding(Encoding::UTF_8))
    end
  end
end
