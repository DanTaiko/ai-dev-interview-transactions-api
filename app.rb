require 'sinatra'
require 'sinatra/json'
require 'active_record'
require 'sqlite3'
require 'json'
require 'active_support/all'

# Server runs in London time (data is stored UTC).
Time.zone_default = ActiveSupport::TimeZone['Europe/London']
Time.zone = 'Europe/London'

ActiveRecord::Base.establish_connection(
  adapter:  'sqlite3',
  database: ENV.fetch('DATABASE_URL', File.expand_path('db/development.sqlite3', __dir__))
)

class Merchant < ActiveRecord::Base
  has_many :transactions
end

class Transaction < ActiveRecord::Base
  belongs_to :merchant

  class << self
    # Accepts bare dates ("2026-05-01") or ISO 8601 datetimes with offset
    # ("2026-05-01T00:00:00+09:00"). Bare dates are treated as UTC day
    # boundaries so results are consistent regardless of server timezone.
    def scope_by_timeframe(from: nil, to: nil)
      scope = all
      scope = scope.where('created_at >= ?', parse_bound(from))                   if from.present?
      scope = scope.where('created_at < ?',  parse_bound(to, date_offset: 1.day)) if to.present?
      scope
    end

    # Accepts a comma-separated list ("USD,EUR"). Unknown codes return no rows.
    def scope_by_currency(currency: nil)
      return all if currency.blank?
      where(currency: currency.split(','))
    end

    private

    def parse_bound(str, date_offset: 0)
      Time.iso8601(with_utc_offset(str)).utc
    rescue ArgumentError
      d = Date.iso8601(str)
      Time.utc(d.year, d.month, d.day) + date_offset
    end

    # Only normalises datetime strings (those with T); bare dates are left unchanged
    # so they fall through to Date.iso8601 in the rescue branch above.
    def with_utc_offset(str)
      return str unless str.include?('T')
      str.match?(/[Zz]$|[+-]\d{2}:?\d{2}$/) ? str : "#{str}Z"
    end
  end
end

class TransactionSerializer
  def initialize(transaction)
    @transaction = transaction
  end

  def as_json
    {
      id: @transaction.id,
      amount: @transaction.amount.to_s,
      currency: @transaction.currency,
      merchant_name: @transaction.merchant.name,
      created_at: @transaction.created_at.iso8601
    }
  end
end

get '/transactions' do
  json Transaction
         .scope_by_timeframe(from: params[:from], to: params[:to])
         .scope_by_currency(currency: params[:currency])
         .includes(:merchant)
         .map { |t| TransactionSerializer.new(t).as_json }
rescue ArgumentError, Date::Error => e
  status 400
  json error: e.message
end
