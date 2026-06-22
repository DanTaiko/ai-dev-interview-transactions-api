# Transactions API — AI-Dev Interview Task

A minimal Sinatra + ActiveRecord API exposing one endpoint: `GET /transactions`.
Your job is to fix a reported bug and add one new feature.

You may use **any AI assistant** (Claude Code, Cursor, Copilot, ChatGPT, ...).
We will be watching how you work with it, not whether you can type fast.

---

## Setup

Ruby 3.0+ required.

```bash
bundle install
bin/setup          # creates SQLite DB, schema, and loads seed data
ruby app.rb        # boots Sinatra on http://localhost:4567
```

Run tests:

```bash
ruby -Itest test/normal/transactions_test.rb
```

---

## The endpoint

```
GET /transactions
```

Query params (all optional):

| param      | example       | meaning                          |
| ---------- | ------------- | -------------------------------- |
| `from`     | `2026-05-01`  | only transactions on/after date  |
| `to`       | `2026-05-31`  | only transactions on/before date |

Response: JSON array of transactions with `id`, `amount`, `currency`, `merchant_name`, `created_at`.

Sanity check after setup:

```bash
curl 'http://localhost:4567/transactions?from=2026-05-01&to=2026-05-31'
```

---

## 1. Bug report

> Hi team. When I filter for May (`?from=2026-05-01&to=2026-05-31`) I see a
> transaction from April 30, and at the same time several of my May 31
> transactions are missing. Some of our users are in Asia / the US — they say
> the filter looks "off" for them in different ways. Please fix.

> — Customer Success

---

## 2. Feature request

Add a multi-value `currency` filter:

- `GET /transactions?currency=USD,EUR` → transactions in USD **or** EUR
- `GET /transactions?currency=USD` → still works (single value)
- Unknown currency code → empty result, no error

---

## Ground rules

- Commit incrementally. We'll review the git log together at the end.
- Tests already exist in [test/normal/transactions_test.rb](test/normal/transactions_test.rb).
  Feel free to add more — and to question existing ones.
- The endpoint should be correct for users in **any timezone**, not just yours.
- Performance matters: imagine this list endpoint serves 10k rows.

---

## What we're evaluating

Not "can you write Ruby." We're looking at:

- How you give the AI context (what you paste, what you describe)
- How you verify the AI's output before trusting it
- How you react when its first answer looks plausible but is wrong
- What you choose to do yourself vs delegate
- How you decide you're done

Talk us through your thinking out loud as you work.
