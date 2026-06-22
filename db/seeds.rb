# Seed data crafted to expose timezone + boundary bugs in the filter.
# All created_at values are stored in UTC (Rails default).
#
# Notable rows:
#   - April 30 23:30 UTC  -> May 1 in Europe/London (TZ trap)
#   - May   1  00:30 UTC  -> April 30 in America/New_York (TZ trap)
#   - May  31  14:00 UTC  -> entire row excluded by naive `<= '2026-05-31'` (boundary trap)
#   - May  31  23:00 UTC  -> same
#
# Mixed currencies (USD, EUR, GBP) so multi-value filter has something to filter.

merchants = %w[Amazon Stripe Apple Google Uber Shopify Netflix].map do |name|
  Merchant.create!(name: name)
end

rows = [
  # April-May boundary in different timezones
  { amount:  87.50, currency: 'USD', created_at: Time.utc(2026, 4, 29, 10,  0) },
  { amount: 142.00, currency: 'EUR', created_at: Time.utc(2026, 4, 30, 14,  0) },
  { amount:  56.25, currency: 'GBP', created_at: Time.utc(2026, 4, 30, 23, 30) }, # late April UTC, May 1 in CET
  { amount:  99.99, currency: 'USD', created_at: Time.utc(2026, 5,  1,  0, 30) }, # early May UTC, April 30 in EST

  # Mid-May (safe, no edge case)
  { amount: 200.00, currency: 'USD', created_at: Time.utc(2026, 5,  5, 12,  0) },
  { amount: 250.00, currency: 'EUR', created_at: Time.utc(2026, 5, 10, 14,  0) },
  { amount:  75.00, currency: 'GBP', created_at: Time.utc(2026, 5, 12,  8,  0) },
  { amount: 310.00, currency: 'USD', created_at: Time.utc(2026, 5, 15, 16, 30) },
  { amount:  44.20, currency: 'EUR', created_at: Time.utc(2026, 5, 18,  9, 15) },
  { amount: 188.00, currency: 'GBP', created_at: Time.utc(2026, 5, 20, 11,  0) },
  { amount: 905.00, currency: 'USD', created_at: Time.utc(2026, 5, 24, 18,  0) },
  { amount: 412.00, currency: 'EUR', created_at: Time.utc(2026, 5, 27, 13, 45) },

  # May 31 — boundary day, multiple times of day to expose off-by-one on `to`
  { amount: 333.00, currency: 'USD', created_at: Time.utc(2026, 5, 31,  0,  5) },
  { amount: 666.00, currency: 'EUR', created_at: Time.utc(2026, 5, 31, 14,  0) }, # excluded by buggy `<= 2026-05-31 00:00`
  { amount: 999.00, currency: 'GBP', created_at: Time.utc(2026, 5, 31, 23,  0) }, # excluded by buggy `<= 2026-05-31 00:00`

  # June (must NOT appear in May filter)
  { amount: 120.00, currency: 'USD', created_at: Time.utc(2026, 6,  1, 10,  0) },
  { amount: 145.00, currency: 'EUR', created_at: Time.utc(2026, 6,  3, 12,  0) },
  { amount:  60.00, currency: 'GBP', created_at: Time.utc(2026, 6,  8, 16,  0) },
  { amount: 410.00, currency: 'USD', created_at: Time.utc(2026, 6, 15,  9, 30) }
]

rows.each_with_index do |attrs, i|
  Transaction.create!(attrs.merge(merchant: merchants[i % merchants.size]))
end
