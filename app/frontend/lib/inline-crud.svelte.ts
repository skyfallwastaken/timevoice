import type { FormDataType } from "@inertiajs/core";
import { page, router, useForm } from "@inertiajs/svelte";

type Named = { id: number; name: string };

export const byName = (a: { name: string }, b: { name: string }) =>
  a.name.localeCompare(b.name);

interface InlineCrudOptions<T extends Named, F extends FormDataType<F>> {
  /** Page prop holding the list, e.g. "clients". */
  key: string;
  routes: {
    create: (workspaceId: string) => string;
    update: (workspaceId: string, id: number) => string;
    delete: (workspaceId: string, id: number) => string;
  };
  createDefaults: F;
  editDefaults: F;
  /** Fill the edit form from an existing record. */
  toForm: (record: T) => F;
  /** Build the optimistic record from form values (merged over `record` on update). */
  toRecord: (form: F, record: T) => T;
  onCreated?: () => void;
}

/**
 * The create form, inline edit row and delete confirmation shared by the
 * Clients, Projects and Tags pages. Creates, renames and deletes show up
 * immediately and roll back if the server rejects them; a failed update
 * reopens its row so the error shows next to the field.
 */
export function createInlineCrud<T extends Named, F extends FormDataType<F>>(
  options: InlineCrudOptions<T, F>,
) {
  const { key, routes } = options;
  const workspaceId = $derived(page.props.auth?.workspace?.hashid as string);
  const createForm = useForm(structuredClone(options.createDefaults));
  const editForm = useForm(structuredClone(options.editDefaults));
  let editingId = $state<number | null>(null);
  let toDelete = $state<T | null>(null);

  type Props = Record<string, T[]>;

  function startEditing(record: T) {
    editForm.clearErrors();
    editingId = record.id;
    Object.assign(editForm, options.toForm(record));
  }

  function cancelEditing() {
    editingId = null;
    editForm.reset();
  }

  function create() {
    if (!workspaceId) return;
    createForm
      .optimistic<Props>((props) => ({
        [key]: [
          ...props[key],
          options.toRecord(createForm.data(), { id: -Date.now() } as T),
        ].sort(byName),
      }))
      .post(routes.create(workspaceId), {
        onSuccess: () => {
          createForm.reset();
          options.onCreated?.();
        },
      });
  }

  function update(id: number) {
    if (!workspaceId) return;
    editingId = null;
    let saved = false;
    editForm
      .optimistic<Props>((props) => ({
        [key]: props[key]
          .map((r) => (r.id === id ? options.toRecord(editForm.data(), r) : r))
          .sort(byName),
      }))
      .patch(routes.update(workspaceId, id), {
        onSuccess: () => {
          saved = true;
          if (editingId === null) editForm.reset();
        },
        // Reopen the row on any failure, unless another row is being edited.
        onFinish: () => {
          if (!saved && editingId === null) editingId = id;
        },
      });
  }

  function confirmDelete() {
    if (toDelete && workspaceId) {
      const { id } = toDelete;
      router
        .optimistic<Props>((props) => ({
          [key]: props[key].filter((r) => r.id !== id),
        }))
        .delete(routes.delete(workspaceId, id));
    }
    toDelete = null;
  }

  /** Enter saves and Escape cancels while focus is inside the edit row. */
  function editKeydown(event: KeyboardEvent, id: number) {
    const target = event.target as HTMLElement;
    if (event.key === "Escape") {
      event.preventDefault();
      cancelEditing();
    } else if (
      event.key === "Enter" &&
      !event.isComposing &&
      target.tagName !== "TEXTAREA" &&
      target.tagName !== "BUTTON"
    ) {
      event.preventDefault();
      if (!editForm.processing) update(id);
    }
  }

  return {
    createForm,
    editForm,
    get editingId() {
      return editingId;
    },
    get toDelete() {
      return toDelete;
    },
    set toDelete(record: T | null) {
      toDelete = record;
    },
    startEditing,
    cancelEditing,
    create,
    update,
    confirmDelete,
    editKeydown,
  };
}
