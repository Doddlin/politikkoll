#!/usr/bin/env bash
# Run manually, on the server, as the "deploy" user — deliberately not
# wired to anything automatic (no CI/CD, no webhook). Just the routine
# deploy steps in one command instead of five. Safe to re-run: idempotent.
set -euo pipefail

cd /var/www/politikkoll

# The systemd units get their env vars from EnvironmentFile=, which only
# applies when systemd itself starts the process — this script runs in a
# plain shell instead, so it never sees POLITIKKOLL_DATABASE_HOST/
# _PASSWORD or RAILS_MASTER_KEY unless it loads the same file itself.
set -a
source /var/www/politikkoll.env
set +a

echo "==> Fetching latest main"
git fetch origin main
# reset --hard, not pull — this checkout is only ever touched by this
# script, so there's nothing local to merge, and this guarantees an exact,
# deterministic match with what's on GitHub every time.
git reset --hard origin/main

echo "==> Installing gems"
# Not `bundle install --deployment ...` — recent Bundler removed that flag
# (it relied on being remembered across invocations, which Bundler no
# longer does); this is the current equivalent, persisted in .bundle/config.
bundle config set --local deployment true
bundle config set --local without development test
bundle install

echo "==> Migrating database"
RAILS_ENV=production bin/rails db:migrate

echo "==> Precompiling assets"
RAILS_ENV=production bin/rails assets:precompile

echo "==> Restarting services"
# Two separate sudo calls, not one — sudoers matches the exact command
# string, and the scoped rule only grants each unit's restart individually,
# not the combined "restart web jobs" form.
sudo systemctl restart politikkoll-web
sudo systemctl restart politikkoll-jobs

echo "==> Deployed $(git rev-parse --short HEAD)"
