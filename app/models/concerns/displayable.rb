# frozen_string_literal: true

module Displayable
  extend ActiveSupport::Concern

  def display_name
    name
  end
end
