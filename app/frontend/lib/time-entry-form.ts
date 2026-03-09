type SelectableProject = {
  id: number;
  billable_default: boolean;
};

type ProjectSelectionForm = {
  project_id: number | null;
  billable: boolean;
};

export function applySelectedProject(
  form: ProjectSelectionForm,
  project: SelectableProject,
) {
  form.project_id = project.id;

  if (project.billable_default) {
    form.billable = true;
  }
}

export function toggleSelectedTag(tagIds: number[], tagId: number) {
  return tagIds.includes(tagId)
    ? tagIds.filter((id) => id !== tagId)
    : [...tagIds, tagId];
}
