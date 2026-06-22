require_relative '../test_helper'

describe 'GET /transactions' do
  let(:merchant) { Merchant.create!(name: 'Acme') }

  it 'returns all transactions when no filter is given' do
    Transaction.create!(merchant: merchant, amount: 100, currency: 'USD', created_at: 3.days.ago)
    Transaction.create!(merchant: merchant, amount: 200, currency: 'EUR', created_at: 1.day.ago)

    get '/transactions'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 2, body.length
  end

  it 'loads merchants in a single query regardless of result size' do
    merchant2 = Merchant.create!(name: 'Globex')
    Transaction.create!(merchant: merchant,  amount: 100, currency: 'USD', created_at: 1.day.ago)
    Transaction.create!(merchant: merchant2, amount: 200, currency: 'USD', created_at: 1.day.ago)
    Transaction.create!(merchant: merchant,  amount: 300, currency: 'USD', created_at: 1.day.ago)

    query_count = 0
    counter = ->(*, **) { query_count += 1 }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      get '/transactions'
    end

    assert_equal 200, last_response.status
    # 1 query for transactions + 1 query for merchants (IN) = 2 total, not 4
    assert query_count <= 2, "Expected ≤2 queries, got #{query_count}"
  end

  it 'filters by `from` date' do
    Transaction.create!(merchant: merchant, amount: 100, currency: 'USD', created_at: 30.days.ago)
    Transaction.create!(merchant: merchant, amount: 200, currency: 'USD', created_at: 5.days.ago)

    get "/transactions?from=#{10.days.ago.to_date.iso8601}"

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '200.0', body.first['amount']
  end

  it 'filters by `from` and `to` range' do
    Transaction.create!(merchant: merchant, amount: 100, currency: 'USD', created_at: 30.days.ago)
    Transaction.create!(merchant: merchant, amount: 200, currency: 'USD', created_at: 15.days.ago)
    Transaction.create!(merchant: merchant, amount: 300, currency: 'USD', created_at: 5.days.ago)

    from = 20.days.ago.to_date.iso8601
    to   = 10.days.ago.to_date.iso8601
    get "/transactions?from=#{from}&to=#{to}"

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '200.0', body.first['amount']
  end

  # ISO 8601 datetime with offset
  it 'from without offset is treated as UTC, not server timezone' do
    # If the server TZ were Europe/London (BST = UTC+1), Time.parse('2026-05-01T01:00:00')
    # without offset would give 2026-05-01 00:00 UTC — wrong. Should stay 01:00 UTC.
    Transaction.create!(merchant: merchant, amount: 1.0, currency: 'USD',
                        created_at: Time.utc(2026, 5, 1, 0, 59))  # before 01:00 UTC → excluded
    Transaction.create!(merchant: merchant, amount: 2.0, currency: 'USD',
                        created_at: Time.utc(2026, 5, 1, 1,  0))  # exactly at → included

    get '/transactions?from=2026-05-01T01:00:00'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '2.0', body.first['amount']
  end

  it 'from with timezone offset converts to UTC lower bound' do
    # 2026-05-01T00:00:00+09:00 = 2026-04-30T15:00:00Z
    Transaction.create!(merchant: merchant, amount: 1.0, currency: 'USD',
                        created_at: Time.utc(2026, 4, 30, 14, 59)) # before → excluded
    Transaction.create!(merchant: merchant, amount: 2.0, currency: 'USD',
                        created_at: Time.utc(2026, 4, 30, 15, 0))  # exactly at bound → included

    get '/transactions?from=2026-05-01T00:00:00%2B09:00'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '2.0', body.first['amount']
  end

  it 'to with timezone offset converts to UTC upper bound' do
    # 2026-05-31T23:59:59+09:00 = 2026-05-31T14:59:59Z
    Transaction.create!(merchant: merchant, amount: 1.0, currency: 'USD',
                        created_at: Time.utc(2026, 5, 31, 14, 59)) # within bound → included
    Transaction.create!(merchant: merchant, amount: 2.0, currency: 'USD',
                        created_at: Time.utc(2026, 5, 31, 15, 0))  # June 1 00:00 Tokyo → excluded

    get '/transactions?to=2026-05-31T23:59:59%2B09:00'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '1.0', body.first['amount']
  end

  # Timezone boundary tests — dates are UTC day boundaries regardless of server TZ
  it 'from filter excludes a transaction at 23:30 UTC on the day before the from date' do
    # 2026-04-30 23:30 UTC is still April 30 in UTC — must not appear with from=2026-05-01
    Transaction.create!(merchant: merchant, amount: 56.25, currency: 'GBP',
                        created_at: Time.utc(2026, 4, 30, 23, 30))
    Transaction.create!(merchant: merchant, amount: 99.99, currency: 'USD',
                        created_at: Time.utc(2026, 5, 1, 0, 30))

    get '/transactions?from=2026-05-01'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '99.99', body.first['amount']
  end

  it 'to filter includes a transaction with sub-second precision at end of the to date' do
    # 23:59:59.500 UTC on the to-date must not be cut off by <= 23:59:59.000
    Transaction.create!(merchant: merchant, amount: 777.0, currency: 'USD',
                        created_at: Time.utc(2026, 5, 31, 23, 59, 59, 500_000))
    Transaction.create!(merchant: merchant, amount: 888.0, currency: 'USD',
                        created_at: Time.utc(2026, 6, 1, 0, 0, 0))

    get '/transactions?to=2026-05-31'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '777.0', body.first['amount']
  end

  it 'to filter includes transactions at any time on the to date in UTC' do
    # 2026-05-31 23:00 UTC is still May 31 in UTC — must appear with to=2026-05-31
    Transaction.create!(merchant: merchant, amount: 999.00, currency: 'GBP',
                        created_at: Time.utc(2026, 5, 31, 23, 0))
    Transaction.create!(merchant: merchant, amount: 120.00, currency: 'USD',
                        created_at: Time.utc(2026, 6, 1, 0, 0))

    get '/transactions?to=2026-05-31'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal '999.0', body.first['amount']
  end

  # Currency filter
  it 'filters by a single currency' do
    Transaction.create!(merchant: merchant, amount: 100, currency: 'USD', created_at: 1.day.ago)
    Transaction.create!(merchant: merchant, amount: 200, currency: 'EUR', created_at: 1.day.ago)
    Transaction.create!(merchant: merchant, amount: 300, currency: 'GBP', created_at: 1.day.ago)

    get '/transactions?currency=USD'

    body = JSON.parse(last_response.body)
    assert_equal 1, body.length
    assert_equal 'USD', body.first['currency']
  end

  it 'filters by multiple comma-separated currencies' do
    Transaction.create!(merchant: merchant, amount: 100, currency: 'USD', created_at: 1.day.ago)
    Transaction.create!(merchant: merchant, amount: 200, currency: 'EUR', created_at: 1.day.ago)
    Transaction.create!(merchant: merchant, amount: 300, currency: 'GBP', created_at: 1.day.ago)

    get '/transactions?currency=USD,EUR'

    body = JSON.parse(last_response.body)
    assert_equal 2, body.length
    assert_equal %w[USD EUR].sort, body.map { |t| t['currency'] }.sort
  end

  it 'returns empty result for unknown currency' do
    Transaction.create!(merchant: merchant, amount: 100, currency: 'USD', created_at: 1.day.ago)

    get '/transactions?currency=XYZ'

    body = JSON.parse(last_response.body)
    assert_equal 200, last_response.status
    assert_equal [], body
  end
end
