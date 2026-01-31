# frozen_string_literal: true

module CurrencyFormatter
  extend ActiveSupport::Concern

  def format_cents(cents)
    "$#{'%.2f' % (cents / 100.0)}"
  end

  def format_rate(cents)
    "$#{'%.2f' % (cents / 100.0)}/hr"
  end
end
