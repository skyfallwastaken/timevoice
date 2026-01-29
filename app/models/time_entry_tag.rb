class TimeEntryTag < ApplicationRecord
  belongs_to :time_entry
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :time_entry_id }
end
