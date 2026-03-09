export const routes = {
  dashboard: {
    index: (workspaceId: string) => `/${workspaceId}/timer`,
    calendar: (workspaceId: string) => `/${workspaceId}/calendar`,
  },

  clients: {
    index: (workspaceId: string) => `/${workspaceId}/clients`,
    create: (workspaceId: string) => `/${workspaceId}/clients`,
    update: (workspaceId: string, id: number) =>
      `/${workspaceId}/clients/${id}`,
    delete: (workspaceId: string, id: number) =>
      `/${workspaceId}/clients/${id}`,
  },

  projects: {
    index: (workspaceId: string) => `/${workspaceId}/projects`,
    create: (workspaceId: string) => `/${workspaceId}/projects`,
    update: (workspaceId: string, id: number) =>
      `/${workspaceId}/projects/${id}`,
    delete: (workspaceId: string, id: number) =>
      `/${workspaceId}/projects/${id}`,
  },

  tags: {
    index: (workspaceId: string) => `/${workspaceId}/tags`,
    create: (workspaceId: string) => `/${workspaceId}/tags`,
    update: (workspaceId: string, id: number) => `/${workspaceId}/tags/${id}`,
    delete: (workspaceId: string, id: number) => `/${workspaceId}/tags/${id}`,
  },

  timeEntries: {
    index: (workspaceId: string) => `/${workspaceId}/timer`,
    create: (workspaceId: string) => `/${workspaceId}/time_entries`,
    update: (workspaceId: string, id: number) =>
      `/${workspaceId}/time_entries/${id}`,
    delete: (workspaceId: string, id: number) =>
      `/${workspaceId}/time_entries/${id}`,
    stop: (workspaceId: string, id: number) =>
      `/${workspaceId}/time_entries/${id}/stop`,
    removeFile: (workspaceId: string, id: number) =>
      `/${workspaceId}/time_entries/${id}/remove_file`,
  },

  invoices: {
    index: (workspaceId: string) => `/${workspaceId}/invoices`,
    show: (workspaceId: string, id: string) => `/${workspaceId}/invoices/${id}`,
    create: (workspaceId: string) => `/${workspaceId}/invoices`,
    update: (workspaceId: string, id: string) =>
      `/${workspaceId}/invoices/${id}`,
    delete: (workspaceId: string, id: string) =>
      `/${workspaceId}/invoices/${id}`,
    pdf: (workspaceId: string, id: string) =>
      `/${workspaceId}/invoices/${id}/pdf`,
    sendEmail: (workspaceId: string, id: string) =>
      `/${workspaceId}/invoices/${id}/send_email`,
  },

  reports: {
    index: (workspaceId: string) => `/${workspaceId}/reports`,
  },

  settings: {
    index: (workspaceId: string) => `/${workspaceId}/settings`,
    workspace: (workspaceId: string) => `/${workspaceId}/settings/workspace`,
    billing: (workspaceId: string) => `/${workspaceId}/settings/billing`,
    developer: (workspaceId: string) => `/${workspaceId}/settings/developer`,
    updateWorkspace: (workspaceId: string) =>
      `/${workspaceId}/settings/workspace`,
    deleteWorkspace: (workspaceId: string) =>
      `/${workspaceId}/settings/workspace`,
    updateBilling: (workspaceId: string) => `/${workspaceId}/settings/billing`,
  },

  oauthApplications: {
    index: (workspaceId: string) => `/${workspaceId}/settings/developer`,
    create: (workspaceId: string) =>
      `/${workspaceId}/settings/developer/applications`,
    update: (workspaceId: string, id: number) =>
      `/${workspaceId}/settings/developer/applications/${id}`,
    delete: (workspaceId: string, id: number) =>
      `/${workspaceId}/settings/developer/applications/${id}`,
    regenerateSecret: (workspaceId: string, id: number) =>
      `/${workspaceId}/settings/developer/applications/${id}/regenerate_secret`,
  },

  memberships: {
    create: (workspaceId: string) => `/${workspaceId}/memberships`,
    delete: (workspaceId: string, id: number) =>
      `/${workspaceId}/memberships/${id}`,
  },

  workspaceInvites: {
    delete: (workspaceId: string, id: number) =>
      `/${workspaceId}/invites/${id}`,
  },

  workspaces: {
    create: "/workspaces",
    switch: "/workspaces/switch",
    delete: (workspaceId: string) => `/${workspaceId}/settings/workspace`,
  },

  invites: {
    show: (token: string) => `/invite/${token}`,
    accept: (token: string) => `/invite/${token}/accept`,
    decline: (token: string) => `/invite/${token}/decline`,
  },

  auth: {
    google: "/auth/google_oauth2",
    logout: "/signout",
    signin: "/signin",
  },

  admin: {
    jobs: "/admin/jobs",
  },

  devTools: {
    letterOpener: "/letter_opener",
  },
};
