# frozen_string_literal: true

# The public API (app/controllers/api/v1) exposes hashids for all resources,
# per docs/api. Workspace and Invoice include Hashidable directly; the other
# resources only need the class-level encode/decode helpers (instance-level
# `to_param` must stay numeric for the web app's routes).
Rails.application.config.to_prepare do
  [ TimeEntry, Project, Tag, Client ].each do |model|
    model.extend(Hashidable::ClassMethods) unless model.respond_to?(:decode_id)
  end
end
