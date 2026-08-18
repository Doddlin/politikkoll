class GeographyController < ApplicationController
  def show
    @areas = Document::AREAS
    @selected_area = params[:area]
    @vote = Vote.find_by(votering_id: params[:votering_id]) if params[:votering_id].present?

    @rows = Geography::DistrictBreakdown.call(area: @selected_area, votering_id: @vote&.votering_id)
    @map = Geography::MapBuilder.call
    @rows_by_constituency = @rows.index_by(&:constituency)
    @parties_by_code = Party.all.index_by(&:code)
  end
end
