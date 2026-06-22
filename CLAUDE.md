# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle install
bin/setup          # drops + recreates SQLite DB, runs schema + seeds

ruby app.rb        # Sinatra dev server on http://localhost:4567

# Run all tests
ruby -Itest test/normal/transactions_test.rb

# Sanity-check the live server
curl 'http://localhost:4567/transactions?from=2026-05-01&to=2026-05-31'
```

There is no Rake, no Rails CLI, no Bundler binstubs beyond `bin/setup`.

## Architecture

Single-file Sinatra app (`app.rb`) with ActiveRecord and SQLite. No separate models directory — `Merchant`, `Transaction`, and `TransactionSerializer` are all defined inline.

- **`app.rb`** — entire application: AR setup, model classes, serializer, route handlers
- **`config.ru`** — Rack entry point for production/Puma, just `require`s app.rb
- **`bin/setup`** — drops/recreates the DB, defines schema inline (no migrations), loads seeds
- **`db/seeds.rb`** — seed data crafted to expose timezone and date-boundary bugs
- **`test/test_helper.rb`** — spins up an in-memory SQLite DB and defines the schema for tests; uses Minitest spec DSL + rack-test
- **`test/normal/transactions_test.rb`** — the test suite

## Key Implementation Details

**Timezone handling:** The app sets `Time.zone` to `Europe/London`. All `created_at` values are stored in UTC. Date-filter params (`from`, `to`) are parsed with `Time.zone.parse`, which interprets bare dates (e.g. `"2026-05-31"`) as midnight in the configured timezone — not UTC and not the user's local time. This is the source of the known date-boundary bug.

**No eager loading on associations:** `TransactionSerializer` calls `transaction.merchant.name`, causing an N+1 query. At scale this needs `includes(:merchant)`.

**Test database:** Tests run against an in-memory SQLite DB defined in `test_helper.rb`. Each spec clears `transactions` and `merchants` via `delete_all` in a `before` block.

## Open Tasks (interview scope)

1. **Bug:** `from`/`to` date filter is timezone-sensitive — should treat dates as UTC day boundaries so results are correct for users in any timezone.
2. **Feature:** Multi-value `currency` filter — `?currency=USD,EUR` returns transactions in USD or EUR; unknown codes return an empty result, no error.
