module Displayable
  extend ActiveSupport::Concern

  def display_name
    name
  end
end
