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
  scope = Transaction.all

  if params[:from].present?
    scope = scope.where('created_at >= ?', Time.zone.parse(params[:from]))
  end

  if params[:to].present?
    scope = scope.where('created_at <= ?', Time.zone.parse(params[:to]))
  end

  json scope.map { |t| TransactionSerializer.new(t).as_json }
end
