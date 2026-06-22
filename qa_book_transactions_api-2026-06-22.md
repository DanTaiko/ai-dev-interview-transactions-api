# QA Book — Transactions API

Setup before running manual tests:

```bash
bin/setup
ruby app.rb   # localhost:4567
```

---

## 1. Date filter — bare date (UTC boundaries)

### 1.1 No filter — returns all rows

```bash
curl -s 'http://localhost:4567/transactions' | jq length
# expect: 19
```

### 1.2 `from` — excludes April, includes May onward

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01' | jq '[.[].created_at] | sort'
# expect: all dates >= 2026-05-01T00:00:00Z, none from April
```

### 1.3 `to` — includes all of May 31 UTC

```bash
curl -s 'http://localhost:4567/transactions?to=2026-05-31' | jq '[.[].created_at] | sort'
# expect: last entry is 2026-05-31T23:00:00Z (999 GBP row), nothing from June
```

### 1.4 `from` + `to` range — May only

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01&to=2026-05-31' | jq length
# expect: 15 (3 April rows and all June rows excluded)
```

### 1.5 Timezone trap — April 30 23:30 UTC must NOT appear in May filter

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01&to=2026-05-31' \
  | jq '[.[].created_at] | map(select(startswith("2026-04")))'
# expect: []
```

### 1.6 Timezone trap — May 31 late-UTC rows must appear in May filter

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01&to=2026-05-31' \
  | jq '[.[].created_at] | map(select(startswith("2026-05-31")))'
# expect: ["2026-05-31T00:05:00Z", "2026-05-31T14:00:00Z", "2026-05-31T23:00:00Z"]
```

---

## 2. Date filter — ISO 8601 datetime with offset

### 2.1 Tokyo user (`+09:00`) filtering May

May 1 00:00 JST = April 30 15:00 UTC → `from` lower bound.  
May 31 23:59:59 JST = May 31 14:59:59 UTC → `to` upper bound.

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01T00:00:00%2B09:00&to=2026-05-31T23:59:59%2B09:00' \
  | jq '[.[].created_at] | sort'
# expect: rows from 2026-04-30T15:00:00Z through 2026-05-31T14:59:59Z inclusive
# The April 30 23:30 UTC seed row (56.25 GBP) IS included — it falls after 15:00 UTC in Tokyo's May
# The May 31 23:00 UTC seed row (999 GBP) is NOT included — it's June 1 in Tokyo
```

### 2.2 New York user (`-05:00`) filtering May

May 1 00:00 EST = May 1 05:00 UTC.

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01T00:00:00-05:00' \
  | jq '[.[].created_at] | map(select(. < "2026-05-01T05:00:00Z"))'
# expect: [] — no rows before May 1 05:00 UTC should appear
```

### 2.3 Mixed: datetime `from`, bare-date `to`

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01T00:00:00%2B09:00&to=2026-05-31' \
  | jq length
# both param types work together without error
```

---

## 3. Currency filter

### 3.1 Single currency

```bash
curl -s 'http://localhost:4567/transactions?currency=USD' | jq '[.[].currency] | unique'
# expect: ["USD"]
```

### 3.2 Multi-value (comma-separated)

```bash
curl -s 'http://localhost:4567/transactions?currency=USD,EUR' | jq '[.[].currency] | unique | sort'
# expect: ["EUR", "USD"]
```

### 3.3 Unknown currency — empty result, no error

```bash
curl -s -o /dev/null -w '%{http_code}' 'http://localhost:4567/transactions?currency=XYZ'
# expect: 200

curl -s 'http://localhost:4567/transactions?currency=XYZ' | jq .
# expect: []
```

### 3.4 Currency combined with date range

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-01&to=2026-05-31&currency=GBP' \
  | jq '[.[].currency] | unique'
# expect: ["GBP"] — only GBP rows within May
```

---

## 4. Edge cases

### 4.1 No params — 200, array

```bash
curl -s -o /dev/null -w '%{http_code}' 'http://localhost:4567/transactions'
# expect: 200
```

### 4.2 All filters together

```bash
curl -s 'http://localhost:4567/transactions?from=2026-05-10&to=2026-05-20&currency=EUR,GBP' \
  | jq '.[] | {amount, currency, created_at}'
# expect: EUR 250 (May 10) and GBP 75 (May 12) — no USD, nothing outside the range
```

### 4.3 Response shape

```bash
curl -s 'http://localhost:4567/transactions' | jq '.[0] | keys | sort'
# expect: ["amount", "created_at", "currency", "id", "merchant_name"]
```
