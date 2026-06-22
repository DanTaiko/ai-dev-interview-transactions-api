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

  # Accepts bare dates ("2026-05-01") or ISO 8601 datetimes with offset
  # ("2026-05-01T00:00:00+09:00"). Bare dates are treated as UTC day
  # boundaries so results are consistent regardless of server timezone.
  def self.scope_by_timeframe(from: nil, to: nil)
    scope = all
    scope = scope.where('created_at >= ?', parse_lower_bound(from)) if from.present?
    scope = scope.where('created_at < ?',  parse_upper_bound(to))   if to.present?
    scope
  end

  # Accepts a comma-separated list ("USD,EUR"). Unknown codes return no rows.
  def self.scope_by_currency(currency: nil)
    return all if currency.blank?
    where(currency: currency.split(','))
  end

  private_class_method def self.parse_lower_bound(str)
    datetime?(str) ? parse_datetime(str) : utc_date(str)
  end

  private_class_method def self.parse_upper_bound(str)
    datetime?(str) ? parse_datetime(str) : utc_date(str) + 1.day
  end

  private_class_method def self.datetime?(str) = str.include?('T')

  # Strings without a UTC offset are treated as UTC, not the server's local timezone.
  private_class_method def self.parse_datetime(str)
    normalized = str.match?(/[Zz]$|[+-]\d{2}:?\d{2}$/) ? str : "#{str}Z"
    Time.parse(normalized).utc
  end

  private_class_method def self.utc_date(str)
    d = Date.iso8601(str)
    Time.utc(d.year, d.month, d.day)
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
end
