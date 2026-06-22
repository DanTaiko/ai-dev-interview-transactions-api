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
end
