module ApplicationHelper
  def ballot_label(ballot)
    t("ballots.#{ballot}", default: ballot)
  end

  def area_label(organ)
    t("areas.#{organ}", default: organ)
  end

  def suggested_questions
    t("suggestions")
  end
end
