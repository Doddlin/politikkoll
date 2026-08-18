#!/usr/bin/env bash
# Run manually, on the server, as the "deploy" user — deliberately not
# wired to anything automatic (no CI/CD, no webhook). Just the routine
# deploy steps in one command instead of five. Safe to re-run: idempotent.
set -euo pipefail

cd /var/www/politikkoll

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
sudo systemctl restart politikkoll-web politikkoll-jobs

echo "==> Deployed $(git rev-parse --short HEAD)"
