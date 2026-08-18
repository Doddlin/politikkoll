namespace :riksdagen do
  desc "Import roll-call votes from data.riksdagen.se. Usage: rails riksdagen:import_votes RM=2023/24 [BET=FiU1]"
  task import_votes: :environment do
    rm = ENV.fetch("RM") { abort "Usage: rails riksdagen:import_votes RM=2023/24 [BET=FiU1]" }
    bet = ENV["BET"]

    puts "Importing votes for rm=#{rm}#{" bet=#{bet}" if bet}..."
    stats = Riksdagen::VoteImporter.call(rm: rm, bet: bet)
    puts "Done. Pages: #{stats[:pages]}, rows seen: #{stats[:rows]}, " \
         "new votes: #{stats[:votes]}, new/updated vote records: #{stats[:vote_records]}"
  end

  desc "Import document metadata from data.riksdagen.se. Usage: rails riksdagen:import_documents RM=2023/24 DOKTYP=bet"
  task import_documents: :environment do
    rm = ENV.fetch("RM") { abort "Usage: rails riksdagen:import_documents RM=2023/24 DOKTYP=bet" }
    doktyp = ENV.fetch("DOKTYP") { abort "Usage: rails riksdagen:import_documents RM=2023/24 DOKTYP=bet" }

    puts "Importing #{doktyp} documents for rm=#{rm}..."
    stats = Riksdagen::DocumentImporter.call(rm: rm, doktyp: doktyp)
    puts "Done. Pages: #{stats[:pages]}, rows seen: #{stats[:rows]}, " \
         "created: #{stats[:created]}, updated: #{stats[:updated]}"
  end

  desc "Backfill document metadata (motioner + betänkanden) for every " \
       "riksmöte in the enrichment relevance window (currently the last " \
       "8, i.e. two election terms). Usage: rails riksdagen:backfill_documents"
  task backfill_documents: :environment do
    $stdout.sync = true # otherwise output redirected to a file (nohup ... > log) sits
                        # in a buffer and is lost if the process ever dies abnormally —
                        # confirmed live: an OOM-killed run left a completely empty log.

    riksmoten = Riksdagen::DocumentImporter.recent_riksmoten
    puts "Backfilling documents for #{riksmoten.size} riksmöten: #{riksmoten.join(', ')}"

    totals = { created: 0, updated: 0 }
    failures = 0
    riksmoten.each do |rm|
      %w[bet mot].each do |doktyp|
        print "  #{rm} #{doktyp}... "
        stats = Riksdagen::DocumentImporter.call(rm: rm, doktyp: doktyp)
        totals[:created] += stats[:created]
        totals[:updated] += stats[:updated]
        puts "#{stats[:rows]} rows seen, #{stats[:created]} new, #{stats[:updated]} updated"
      rescue => e
        failures += 1
        puts "FAILED: #{e.class}: #{e.message}"
        Rails.logger.error("[backfill_documents] #{rm} #{doktyp} failed: #{e.message}")
      end
    end

    puts "Done. #{totals[:created]} new documents, #{totals[:updated]} updated, " \
         "#{failures} failed, across #{riksmoten.size} riksmöten." \
         "#{" Re-run to retry the failed ones — already-imported documents are skipped (0 new/updated), so it's safe to run again." if failures.positive?}"
  end

  desc "Import votes for every betänkande that hasn't been checked yet — a " \
       "one-time bulk catch-up, not the small trickle ImportMissingVotesJob " \
       "does on its 10-minute schedule. Run after backfill_documents. " \
       "Usage: rails riksdagen:backfill_votes"
  task backfill_votes: :environment do
    $stdout.sync = true # see backfill_documents — same reasoning, matters even
                        # more here given how much longer this one runs.

    candidates = Document.where(doktyp: "bet", votes_checked_at: nil)
    total = candidates.count
    puts "Importing votes for #{total} betänkanden — this will take a while " \
         "(one Riksdagen API call per betänkande, paced to be a considerate " \
         "caller rather than as fast as possible)."

    processed = 0
    new_votes = 0
    failures = 0
    consecutive_failures = 0

    candidates.find_each do |document|
      stats = Riksdagen::VoteImporter.call(rm: document.rm, bet: document.beteckning)
      document.update!(votes_checked_at: Time.current)
      new_votes += stats[:votes]
      processed += 1
      consecutive_failures = 0
      print "\r  #{processed}/#{total} betänkanden checked, #{new_votes} new voteringar so far"
      sleep 1
    rescue => e
      failures += 1
      consecutive_failures += 1
      # Deliberately NOT marking votes_checked_at here — a network/rate-limit
      # failure is not the same as "checked, no vote data exists." Confirmed
      # live: a run that did mark it permanently lost SoU9 (2018/19) and
      # anything else it failed on to a plain ECONNRESET, since nothing
      # would ever retry a betänkande with votes_checked_at already set.
      # Left nil, this one's picked up again next run or by
      # ImportMissingVotesJob's normal schedule.
      warn "\n  failed: #{document.rm} #{document.beteckning}: #{e.message}"

      # Several in a row is a real signal we're being throttled, not just
      # unlucky once — pause properly rather than hammer straight through
      # the rest of the list at the same pace and make it worse.
      if consecutive_failures >= 3
        cooldown = [ 30 * consecutive_failures, 300 ].min
        warn "  #{consecutive_failures} failures in a row — pausing #{cooldown}s before continuing"
        sleep cooldown
      end
    end

    puts
    puts "Done. Checked #{processed}/#{total} betänkanden, #{new_votes} new voteringar, #{failures} failures " \
         "(failures are left with votes_checked_at unset, so just re-running this task retries them)."
  end

  desc "Fetch full text + embeddings for imported documents. " \
       "Usage: rails riksdagen:enrich_documents [TITLE_LIKE=skatt] [PARTY=S] [DOKTYP=mot] [LIMIT=50]"
  task enrich_documents: :environment do
    scope = Document.where(full_text: nil)
    scope = scope.where("titel ILIKE ?", "%#{ENV["TITLE_LIKE"]}%") if ENV["TITLE_LIKE"].present?
    scope = scope.where(party_code: ENV["PARTY"]) if ENV["PARTY"].present?
    scope = scope.where(doktyp: ENV["DOKTYP"]) if ENV["DOKTYP"].present?
    scope = scope.limit(ENV.fetch("LIMIT", 50).to_i)

    documents = scope.to_a
    puts "Fetching full text for #{documents.size} documents..."

    fetched = documents.select do |document|
      Riksdagen::FullTextFetcher.call(document)
    rescue Riksdagen::FullTextFetcher::Error => e
      warn "  skip #{document.dok_id}: #{e.message}"
      false
    end
    puts "Fetched #{fetched.size}/#{documents.size}."

    to_embed = fetched.select { |d| d.full_text.present? }
    puts "Embedding #{to_embed.size} documents..."
    embedded = Embeddings::DocumentEmbedder.call(to_embed)
    puts "Done. Embedded #{embedded}."
  end
end
