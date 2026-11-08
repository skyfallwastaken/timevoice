import type { FormDataType } from "@inertiajs/core";
import { page, router, useForm } from "@inertiajs/svelte";
import { tick } from "svelte";

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

  // Closing an edit row unmounts the focused field; give focus back to the
  // row's Edit button (marked with data-edit-id) unless it moved elsewhere.
  function restoreFocus(id: number) {
    tick().then(() => {
      if (document.activeElement && document.activeElement !== document.body)
        return;
      document.querySelector<HTMLElement>(`[data-edit-id="${id}"]`)?.focus();
    });
  }

  function cancelEditing() {
    const id = editingId;
    editingId = null;
    editForm.reset();
    if (id !== null) restoreFocus(id);
  }

  function create() {
    if (!workspaceId || createForm.processing) return;
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
    restoreFocus(id);
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
        // Reopen the row on any failure, unless another row is being edited;
        // then drop the errors so they don't show on that other row (the
        // server's flash message still reports the failure).
        onFinish: () => {
          if (saved) return;
          if (editingId === null) editingId = id;
          else if (editingId !== id) editForm.clearErrors();
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

  /** Enter saves and Escape cancels; attach to the edit row's wrapper. */
  function editKeydown(event: KeyboardEvent, id: number) {
    // Keys pressed while an IME is composing belong to the IME.
    if (event.isComposing) return;
    const target = event.target as HTMLElement;
    if (event.key === "Escape") {
      event.preventDefault();
      cancelEditing();
    } else if (
      event.key === "Enter" &&
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
