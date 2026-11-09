class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Case-insensitive, then exact: the same order as byName in
  # app/frontend/lib/inline-crud.svelte.ts, so optimistic rows land where the
  # server puts them. Sorted here because ORDER BY name follows the database
  # collation, which differs between SQLite and Postgres.
  def self.sorted_by_name
    all.sort_by { |record| [ record.name.downcase, record.name ] }
  end
end
