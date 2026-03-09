<script lang="ts">
  import { page, router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import Modal from "./Modal.svelte";
  import Button from "./Button.svelte";
  import FormField from "./FormField.svelte";
  import SelectInput from "./SelectInput.svelte";
  import TextInput from "./TextInput.svelte";
  import ChipButton from "./ChipButton.svelte";
  import IconButton from "./IconButton.svelte";
  import { Paperclip, X, Check } from "lucide-svelte";
  import { formatFileSize } from "../lib/format";
  import { routes } from "../lib/routes";
  import { toggleSelectedTag } from "../lib/time-entry-form";
  import type { TimeEntry, Project, Tag } from "../types";
  import ConfirmDeleteModal from "./ConfirmDeleteModal.svelte";

  interface Props {
    entry: TimeEntry | null;
    projects: Project[];
    tags: Tag[];
    open: boolean;
    onClose: () => void;
    onDelete?: (entry: TimeEntry) => void;
  }

  let { entry, projects, tags, open, onClose, onDelete }: Props = $props();

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);
  let editFileInput: HTMLInputElement | null = $state(null);

  let editForm = useForm({
    description: "",
    project_id: "" as string,
    tag_ids: [] as number[],
    billable: false,
    files: [] as File[],
  });

  let showDeleteModal = $state(false);

  $effect(() => {
    if (entry) {
      $editForm.description = entry.description || "";
      $editForm.project_id = entry.project?.id?.toString() || "";
      $editForm.tag_ids = (entry.tags || []).map((t) => t.id);
      $editForm.billable = !!entry.billable;
      $editForm.files = [];
    }
  });

  function toggleTag(tagId: number) {
    $editForm.tag_ids = toggleSelectedTag($editForm.tag_ids, tagId);
  }

  function handleEditFileSelect(event: Event) {
    const target = event.target as HTMLInputElement;
    if (target.files) {
      const files = Array.from(target.files);
      const existingCount =
        (entry?.files?.length || 0) + $editForm.files.length;
      if (existingCount + files.length > 3) {
        alert("You can only attach up to 3 files");
        target.value = "";
        return;
      }
      $editForm.files = [...$editForm.files, ...files].slice(
        0,
        3 - (entry?.files?.length || 0),
      );
      target.value = "";
    }
  }

  function removeEditFile(index: number) {
    $editForm.files = $editForm.files.filter((_, i) => i !== index);
  }

  function deleteExistingFile(blobId: number) {
    if (!entry || !workspaceId) return;
    router.delete(
      `${routes.timeEntries.removeFile(workspaceId, entry.id)}?blob_id=${blobId}`,
      {
        preserveScroll: true,
        onSuccess: () => {
          if (entry) {
            entry.files =
              entry.files?.filter((f) => f.blob_id !== blobId) || [];
          }
        },
      },
    );
  }

  function saveEdit() {
    if (!entry || !workspaceId) return;

    $editForm
      .transform((data) => {
        const formData = new FormData();
        formData.append("time_entry[description]", data.description);
        formData.append("time_entry[project_id]", data.project_id);
        formData.append("time_entry[billable]", data.billable.toString());
        data.tag_ids.forEach((id) => {
          formData.append("time_entry[tag_ids][]", id.toString());
        });
        data.files.forEach((file) => {
          formData.append("time_entry[files][]", file);
        });
        return formData;
      })
      .patch(routes.timeEntries.update(workspaceId, entry.id), {
        preserveScroll: true,
        onSuccess: () => {
          onClose();
          $editForm.reset();
        },
      });
  }

  function openDeleteModal() {
    if (entry && onDelete) {
      onDelete(entry);
    } else {
      showDeleteModal = true;
    }
  }

  function closeDeleteModal() {
    showDeleteModal = false;
  }

  function confirmDelete() {
    if (!entry || !workspaceId) return;
    router.delete(routes.timeEntries.delete(workspaceId, entry.id), {
      preserveScroll: true,
      onSuccess: () => {
        closeDeleteModal();
        onClose();
      },
    });
  }

  function handleClose() {
    onClose();
    $editForm.reset();
  }
</script>

<Modal {open} title="Edit Entry" onclose={handleClose} maxWidth="max-w-lg">
  <div>
    <FormField id="edit-description" label="Description">
      {#snippet children({ describedBy })}
        <TextInput
          id="edit-description"
          bind:value={$editForm.description}
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <FormField id="edit-project" label="Project">
      {#snippet children({ describedBy })}
        <SelectInput
          id="edit-project"
          tone="blue"
          bind:value={$editForm.project_id}
          aria-describedby={describedBy}
        >
          <option value="">No project</option>
          {#each projects as project}
            <option value={project.id.toString()}>{project.name}</option>
          {/each}
        </SelectInput>
      {/snippet}
    </FormField>

    <div>
      <span class="block text-sm font-medium text-fg-secondary mb-1"
        >Billable</span
      >
      <button
        type="button"
        class="w-full px-4 py-2 border rounded-[10px] transition-colors duration-150 {$editForm.billable
          ? 'border-bright-green text-bright-green'
          : 'border-bg-tertiary text-fg-muted hover:text-fg-primary'}"
        aria-pressed={$editForm.billable}
        onclick={() => ($editForm.billable = !$editForm.billable)}
      >
        {$editForm.billable ? "Billable" : "Non-billable"}
      </button>
    </div>
  </div>

  <div>
    <span class="block text-sm font-medium text-fg-secondary mb-2">Tags</span>
    {#if tags.length === 0}
      <p class="text-sm text-fg-muted">No tags yet.</p>
    {:else}
      <div class="flex flex-wrap gap-2">
        {#each tags as tag}
          <ChipButton
            type="button"
            selected={$editForm.tag_ids.includes(tag.id)}
            class={$editForm.tag_ids.includes(tag.id)
              ? "border-bright-green text-bright-green"
              : "text-fg-muted hover:text-fg-primary"}
            aria-pressed={$editForm.tag_ids.includes(tag.id)}
            onclick={() => toggleTag(tag.id)}
          >
            {tag.name}
          </ChipButton>
        {/each}
      </div>
    {/if}
  </div>

  <div>
    <span class="block text-sm font-medium text-fg-secondary mb-2"
      >Attachments</span
    >
    <div class="space-y-2">
      {#if entry?.files && entry.files.length > 0}
        <div class="flex flex-wrap gap-2">
          {#each entry.files as file}
            <div
              class="flex items-center gap-2 px-3 py-1.5 bg-bg-primary border border-bg-tertiary rounded-lg text-sm"
            >
              <Paperclip class="w-3 h-3 text-fg-muted" />
              <span class="truncate max-w-37.5">{file.filename}</span>
              <span class="text-fg-muted text-xs"
                >({formatFileSize(file.byte_size)})</span
              >
              <button
                type="button"
                onclick={() => deleteExistingFile(file.blob_id)}
                class="p-1 text-fg-muted hover:text-bright-red rounded transition-colors"
                aria-label="Delete file"
              >
                <X class="w-3 h-3" />
              </button>
            </div>
          {/each}
        </div>
      {/if}

      {#if $editForm.files.length > 0}
        <div class="flex flex-wrap gap-2">
          {#each $editForm.files as file, index}
            <div
              class="flex items-center gap-2 px-3 py-1.5 bg-bg-primary border border-bright-blue rounded-lg text-sm"
            >
              <span class="truncate max-w-37.5">{file.name}</span>
              <span class="text-fg-muted text-xs"
                >({formatFileSize(file.size)})</span
              >
              <span class="text-xs text-bright-blue">(new)</span>
              <button
                type="button"
                onclick={() => removeEditFile(index)}
                class="p-1 text-fg-muted hover:text-bright-red rounded transition-colors"
                aria-label="Remove file"
              >
                <X class="w-3 h-3" />
              </button>
            </div>
          {/each}
        </div>
      {/if}

      {#if (entry?.files?.length || 0) + $editForm.files.length < 3}
        <div class="flex items-center gap-2">
          <input
            bind:this={editFileInput}
            type="file"
            multiple
            accept="*/*"
            class="hidden"
            onchange={handleEditFileSelect}
          />
          <button
            type="button"
            onclick={() => editFileInput?.click()}
            class="flex items-center gap-2 px-3 py-1.5 text-sm text-fg-muted hover:text-fg-primary border border-bg-tertiary rounded-lg hover:border-bright-blue transition-colors duration-150"
          >
            <Paperclip class="w-4 h-4" />
            Add Files ({(entry?.files?.length || 0) + $editForm.files.length}/3)
          </button>
          <span class="text-xs text-fg-muted">Max 10MB each</span>
        </div>
      {/if}
    </div>
  </div>

  {#snippet footer()}
    <div class="flex items-center justify-between">
      <Button
        variant="ghost"
        type="button"
        onclick={openDeleteModal}
        disabled={$editForm.processing}
        class="text-bright-red hover:text-bright-red hover:bg-bright-red/10"
      >
        Delete
      </Button>
      <div class="flex items-center gap-2">
        <Button
          variant="ghost"
          type="button"
          onclick={handleClose}
          disabled={$editForm.processing}
        >
          Cancel
        </Button>
        <Button
          tone="blue"
          type="button"
          onclick={saveEdit}
          disabled={$editForm.processing}
        >
          <Check class="w-4 h-4" aria-hidden="true" />
          {$editForm.processing ? "Saving..." : "Save"}
        </Button>
      </div>
    </div>
  {/snippet}
</Modal>

{#if !onDelete}
  <ConfirmDeleteModal
    bind:open={showDeleteModal}
    title="Delete Time Entry"
    itemName="this time entry"
    warningMessage="This action cannot be undone."
    onConfirm={confirmDelete}
    onClose={closeDeleteModal}
  >
    {#snippet details()}
      {#if entry?.description}
        <p class="text-sm text-fg-muted italic">
          "{entry.description}"
        </p>
      {/if}
    {/snippet}
  </ConfirmDeleteModal>
{/if}
