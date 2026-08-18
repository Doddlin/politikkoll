class DocumentsController < ApplicationController
  PER_PAGE = 24

  def index
    @scope = Document.order(published_at: :desc)
    @scope = @scope.where(organ: params[:area]) if params[:area].present?
    @scope = @scope.where(party_code: params[:party]) if params[:party].present?
    @scope = @scope.where(doktyp: params[:doktyp]) if params[:doktyp].present?

    @total_count = @scope.count
    @page = [ params[:page].to_i, 1 ].max
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @documents = @scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

    @areas = Document::AREAS
    @parties = Party.where.not(code: "-").order(:code)

    @selected_area = params[:area]
    @selected_party = params[:party]
    @selected_doktyp = params[:doktyp]
  end

  def show
    @document = Document.find_by!(dok_id: params[:id])
    @party = Party.find_by(code: @document.party_code)
    @related_votes = Vote.where(rm: @document.rm, beteckning: @document.beteckning).order(:punkt) if @document.doktyp == "bet"
  end
end
