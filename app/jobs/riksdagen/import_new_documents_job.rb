module Riksdagen
  # Keeps every riksmöte in DocumentImporter::START_RIKSMOTE..current synced
  # with Riksdagen's document list — the recurring counterpart to
  # riksdagen:backfill_documents. Runs the whole fixed span every time
  # (not just the current riksmöte) so a riksmöte can never sit at zero
  # waiting for someone to remember the manual rake task — the span only
  # ever grows as riksmöten roll over, never leaving a gap in the middle.
  # Cheap to run often: DocumentImporter no-ops (no save) for rows
  # unchanged since the last run, and the whole span is currently only a
  # few riksmöten, a couple dozen pages total.
  # Once a betänkande lands, ImportMissingVotesJob picks up its votes on
  # its own 10-minute schedule — this job doesn't need to touch votes.
  class ImportNewDocumentsJob < ApplicationJob
    queue_as :default

    def perform
      DocumentImporter.recent_riksmoten.each do |rm|
        %w[bet mot].each do |doktyp|
          DocumentImporter.call(rm: rm, doktyp: doktyp)
        rescue => e
          Rails.logger.error("[ImportNewDocumentsJob] #{rm} #{doktyp} failed: #{e.message}")
        end
      end
    end
  end
end
