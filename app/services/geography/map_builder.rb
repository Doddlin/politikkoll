module Geography
  # Projects the 29 Riksdag valkrets (electoral district) polygons — dissolved
  # from Valmyndigheten's own kommun boundaries per the official
  # kommun→valkrets split for Stockholm/Skåne/Västra Götaland — into SVG path
  # data once at boot. Equirectangular projection with a cosine-latitude
  # correction is plenty accurate for a thematic (non-navigational) map.
  class MapBuilder
    GEOJSON_PATH = Rails.root.join("lib/data/valkretsar.geojson")
    TARGET_WIDTH = 600.0

    Result = Struct.new(:paths, :view_box, keyword_init: true)

    class << self
      def call
        @result ||= build
      end

      private

      def build
        features = JSON.parse(File.read(GEOJSON_PATH))["features"]

        lons, lats = [], []
        features.each { |f| each_ring(f["geometry"]) { |ring| ring.each { |lon, lat| lons << lon; lats << lat } } }
        min_lon, max_lon = lons.minmax
        min_lat, max_lat = lats.minmax
        cos_lat = Math.cos((min_lat + max_lat) / 2.0 * Math::PI / 180.0)

        scale = TARGET_WIDTH / ((max_lon - min_lon) * cos_lat)
        height = (max_lat - min_lat) * scale

        project = lambda do |(lon, lat)|
          [ ((lon - min_lon) * cos_lat * scale).round(2), ((max_lat - lat) * scale).round(2) ]
        end

        paths = features.each_with_object({}) do |f, h|
          h[f["properties"]["valkrets"]] = build_path(f["geometry"], project)
        end

        Result.new(paths: paths, view_box: "0 0 #{TARGET_WIDTH.round(2)} #{height.round(2)}")
      end

      def each_ring(geometry)
        case geometry["type"]
        when "Polygon" then geometry["coordinates"].each { |ring| yield ring }
        when "MultiPolygon" then geometry["coordinates"].each { |poly| poly.each { |ring| yield ring } }
        end
      end

      def build_path(geometry, project)
        segments = []
        each_ring(geometry) do |ring|
          points = ring.map { |pt| project.call(pt) }
          segments << "M#{points.map { |x, y| "#{x},#{y}" }.join("L")}Z"
        end
        segments.join(" ")
      end
    end
  end
end
