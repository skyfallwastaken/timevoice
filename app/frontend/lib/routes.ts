export const routes = {

  dashboard: {
    index: (workspaceId: string) => `/${workspaceId}/timer`,
    calendar: (workspaceId: string) => `/${workspaceId}/calendar`
  },

  clients: {
    index: (workspaceId: string) => `/${workspaceId}/clients`,
    create: (workspaceId: string) => `/${workspaceId}/clients`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/clients/${id}`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/clients/${id}`
  },

  projects: {
    index: (workspaceId: string) => `/${workspaceId}/projects`,
    create: (workspaceId: string) => `/${workspaceId}/projects`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/projects/${id}`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/projects/${id}`
  },

  tags: {
    index: (workspaceId: string) => `/${workspaceId}/tags`,
    create: (workspaceId: string) => `/${workspaceId}/tags`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/tags/${id}`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/tags/${id}`
  },

  timeEntries: {
    index: (workspaceId: string) => `/${workspaceId}/timer`,
    create: (workspaceId: string) => `/${workspaceId}/time_entries`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/time_entries/${id}`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/time_entries/${id}`,
    start: (workspaceId: string) => `/${workspaceId}/time_entries/start`,
    stop: (workspaceId: string, id: number) => `/${workspaceId}/time_entries/${id}/stop`
  },

  invoices: {
    index: (workspaceId: string) => `/${workspaceId}/invoices`,
    show: (workspaceId: string, id: number) => `/${workspaceId}/invoices/${id}`,
    create: (workspaceId: string) => `/${workspaceId}/invoices`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/invoices/${id}`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/invoices/${id}`,
    generate: (workspaceId: string) => `/${workspaceId}/invoices/generate`,
    download: (workspaceId: string, id: number) => `/${workspaceId}/invoices/${id}/download`
  },

  reports: {
    index: (workspaceId: string) => `/${workspaceId}/reports`
  },

  settings: {
    workspace: (workspaceId: string) => `/${workspaceId}/settings/workspace`,
    billing: (workspaceId: string) => `/${workspaceId}/settings/billing`,
    developer: (workspaceId: string) => `/${workspaceId}/settings/developer`
  },

  oauthApplications: {
    index: (workspaceId: string) => `/${workspaceId}/settings/developer`,
    create: (workspaceId: string) => `/${workspaceId}/settings/developer/applications`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/settings/developer/applications/${id}`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/settings/developer/applications/${id}`,
    regenerateSecret: (workspaceId: string, id: number) => `/${workspaceId}/settings/developer/applications/${id}/regenerate_secret`
  },

  memberships: {
    create: (workspaceId: string) => `/${workspaceId}/memberships`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/memberships/${id}`
  },

  workspaces: {
    switch: (workspaceId: string) => `/${workspaceId}/switch`,
    delete: (workspaceId: string) => `/${workspaceId}/settings/workspace`
  },

  auth: {
    google: '/auth/google_oauth2',
    logout: '/logout'
  }
}
