# frozen_string_literal: true

class OauthApplication < ApplicationRecord
  include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

  self.table_name = "oauth_applications"

  belongs_to :workspace

  TRUST_LEVELS = %w[community official].freeze

  SCOPES = {
    read: {
      title: "View account info",
      description: "View basic information about your account and workspaces"
    },
    write: {
      title: "Modify account settings",
      description: "Update your account settings and preferences"
    },
    time_entries: {
      title: "Manage time entries",
      description: "Create, view, edit and delete time entries"
    },
    clients: {
      title: "Manage clients",
      description: "Create, view, edit and delete clients in your workspaces"
    },
    projects: {
      title: "Manage projects",
      description: "Create, view, edit and delete projects in your workspaces"
    },
    tags: {
      title: "Manage tags",
      description: "Create, view, edit and delete tags in your workspaces"
    },
    invoices: {
      title: "Manage invoices",
      description: "Create, view, edit and delete invoices"
    }
  }.freeze

  validates :trust_level, inclusion: { in: TRUST_LEVELS }
  validates :name, presence: true, length: { maximum: 255 }

  scope :for_user, ->(user) { where(user: user) }

  def community?
    trust_level == "community"
  end

  def official?
    trust_level == "official"
  end

  def self.scope_descriptions
    SCOPES.transform_values { |v| v[:description] }
  end

  def self.scope_info
    SCOPES
  end

  def scopes_array
    scopes.to_a
  end
end
