# Deploying politikkoll via systemd + Caddy

An alternative to the Kamal/Docker path in `config/deploy.yml` — runs Puma
directly as a systemd service on the box, behind the Caddy instance that
already fronts other services there. Pick one path; both aren't needed.

## The box this targets isn't dedicated — plan accordingly

`systemctl status` on the target (hostname `clarifyr`) shows it's already
running two other full app stacks plus a transcription service, all on
2 vCPUs / 3.8GB RAM:

- **clarifyr-web** (Puma, port 3000) + **clarifyr-jobs** (Solid Queue) +
  **clarifyr-sidekiq** (Sidekiq) + **clarifyr-video-processor** (a Python/
  Whisper transcription service — the one genuinely CPU-hungry thing here)
- **tikka-web** (Puma, port 3001) + **tikka-web-queue** (Solid Queue)
- **redis-server**
- **postgresql@16-main** — one shared Postgres 16 cluster already holding
  both clarifyr's and tikka_web's databases

politikkoll joins this as a third stack, not onto a spare box. The units
here are sized accordingly (see the `MemoryHigh`/`MemoryMax`/`CPUQuota`
comments in each `.service` file) — start there and watch real usage via
`systemctl status` / `journalctl` rather than assuming headroom.

**Port 3002** — 3000 and 3001 are both already taken.

**Don't retune shared Postgres settings from this repo.** `shared_buffers`,
`work_mem`, etc. are cluster-wide, not per-database — changing them affects
clarifyr and tikka_web's already-running Postgres too. If you want tuning
help, share the current `postgresql.conf` first rather than applying
generic advice sized for a dedicated instance.

## One-time server setup

1. **Ruby.** Install the version in `.ruby-version` (rbenv assumed by the
   unit files' PATH — adjust if you use rvm/system Ruby).

2. **pgvector for the existing Postgres 16.** Confirm whether it's already
   installed (clarifyr/tikka_web may not use it) — `psql -c "\dx"` in any
   existing database. If not: `apt install postgresql-16-pgvector`, or
   build from source at the same version this app's dev data was created
   with (0.8.2) to avoid any HNSW index format surprises.

3. **Database role + database**, in the existing shared cluster:
   ```
   CREATE ROLE politikkoll WITH LOGIN PASSWORD '<pick one, put it in politikkoll.env>';
   CREATE DATABASE politikkoll_production OWNER politikkoll;
   \c politikkoll_production
   CREATE EXTENSION vector;
   ```

4. **Restore the existing data.** `tmp/politikkoll_production_seed.sql` (in
   this repo checkout, not committed to git — it's 64MB) is a plain-SQL
   `pg_dump --format=plain` of the local dev database: every imported
   document, vote, member, and manifesto chunk, including the Mistral
   embeddings already paid for and computed. Restoring it means production
   starts with all of that already searchable, instead of re-running every
   import/enrichment job (and every embedding API call) from scratch.

   This is a **plain SQL dump on purpose, not the custom `-Fc` format** —
   the source database is Postgres 18 (local dev machine) and the target
   is Postgres 16, and `pg_dump`/`pg_restore` refuse cross-major-version
   moves in the *newer-to-older* direction when using the binary custom
   format (confirmed locally: PG16's `pg_dump` refuses to even connect to
   a PG18 server). Plain SQL sidesteps that entirely — it's just portable
   `CREATE TABLE`/`COPY` statements, which any target version can run.

   This was verified for real, not assumed: built pgvector 0.8.2 against a
   scratch local Postgres 16 instance, restored this exact dump into it,
   and confirmed every table matches the source row-for-row (documents
   2728, vote_records 24081, manifesto_chunks 113, etc.), that 1481
   documents came through with embeddings intact, that the HNSW indexes
   exist post-restore, and that a real `<=>` similarity query against them
   returns correctly ranked results. That's the same restore command
   below, just against a disposable local instance instead of the real box.

   Transfer it to the box (adjust host/path):
   ```
   scp tmp/politikkoll_production_seed.sql you@server:/tmp/
   ```
   Then, on the server, against the empty `politikkoll_production` database
   created in step 3:
   ```
   psql -h 127.0.0.1 -U politikkoll -d politikkoll_production \
     -f /tmp/politikkoll_production_seed.sql
   ```
   This restores schema, data, *and* the `schema_migrations` table — so the
   app already considers itself migrated. `bin/rails db:migrate` in the
   deploy steps below is still safe to run every time; it's a no-op unless
   a new migration has landed since this dump was taken.

5. **Clone the app** into `/var/www/politikkoll` — this box keeps app code
   under `/var/www/<appname>`, not under the deploy user's home (that's
   reserved for tooling like rbenv, per clarifyr's `/home/deploy/whisper-venv`).
   Owned by the existing `deploy` user, no new system user needed:
   ```
   sudo mkdir -p /var/www/politikkoll
   sudo chown deploy:deploy /var/www/politikkoll
   sudo -u deploy git clone <this repo> /var/www/politikkoll
   ```
   (Or, if it's already there owned by root: `sudo chown -R deploy:deploy
   /var/www/politikkoll`.) `deploy` needs to own the tree, not just have it
   readable, for routine things like `bundle install` writing `Gemfile.lock`.

6. **Env file.** Copy `deploy/systemd/politikkoll.env.sample` to
   `/var/www/politikkoll.env` — a sibling of the app checkout, not inside
   it, so it's never at risk of being swept up by git — fill in real values
   (`RAILS_MASTER_KEY` is the contents of `config/master.key` — copy it
   over, don't regenerate it, or `credentials.yml.enc` becomes unreadable).
   Then:
   ```
   sudo chown deploy:deploy /var/www/politikkoll.env
   sudo chmod 600 /var/www/politikkoll.env
   ```

7. **Install both systemd units:**
   ```
   sudo cp deploy/systemd/politikkoll-web.service deploy/systemd/politikkoll-jobs.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now politikkoll-web politikkoll-jobs
   systemctl status politikkoll-web politikkoll-jobs
   journalctl -u politikkoll-web -u politikkoll-jobs -f   # watch them boot
   ```

8. **Wire up Caddy.** Add the block from `deploy/Caddyfile` to the existing
   Caddyfile on the box, then:
   ```
   caddy validate --config /etc/caddy/Caddyfile
   sudo systemctl reload caddy
   ```

9. **Point DNS** for politikkoll.se (and www) at the box, then confirm
   `https://politikkoll.se/up` returns 200 once Caddy has issued its
   certificate.

## Routine deploys after that

From `/var/www/politikkoll` as the `deploy` user:
```
git pull
bundle install --deployment --without development test
RAILS_ENV=production bin/rails db:migrate
RAILS_ENV=production bin/rails assets:precompile
sudo systemctl restart politikkoll-web politikkoll-jobs
```
