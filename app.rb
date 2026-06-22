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

  def self.scope_by_timeframe(from: nil, to: nil)
    scope = all
    scope = scope.where('created_at >= ?', parse_lower_bound(from)) if from.present?
    scope = scope.where('created_at <= ?', parse_upper_bound(to))   if to.present?
    scope
  end

  def self.scope_by_currency(currency: nil)
    return all if currency.blank?
    where(currency: currency.split(','))
  end

  private_class_method def self.parse_lower_bound(str)
    datetime?(str) ? Time.parse(str).utc : utc_date(str)
  end

  private_class_method def self.parse_upper_bound(str)
    datetime?(str) ? Time.parse(str).utc : utc_date(str) + 1.day - 1.second
  end

  private_class_method def self.datetime?(str) = str.include?('T')

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
         .map { |t| TransactionSerializer.new(t).as_json }
end
