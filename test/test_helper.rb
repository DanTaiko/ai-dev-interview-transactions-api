require_relative '../app'
require 'minitest/autorun'
require 'rack/test'

ActiveRecord::Base.remove_connection
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :merchants do |t|
    t.string :name, null: false
    t.timestamps
  end

  create_table :transactions do |t|
    t.references :merchant, null: false
    t.decimal :amount, precision: 10, scale: 2, null: false
    t.string :currency, null: false
    t.timestamps
  end
end

module RackHelpers
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
end

class Minitest::Spec
  include RackHelpers

  before do
    Transaction.delete_all
    Merchant.delete_all
  end
end
