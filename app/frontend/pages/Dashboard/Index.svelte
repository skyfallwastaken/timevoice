<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import TimerInput from "../../components/TimerInput.svelte";
  import { page, router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import {
    Edit2,
    Trash2,
    DollarSign,
    Check,
    X,
    Search,
    Filter,
    ChevronDown,
    ChevronUp,
    Paperclip,
  } from "lucide-svelte";
  import Modal from "../../components/Modal.svelte";
  import {
    formatShortDate,
    formatTime,
    formatFileSize,
  } from "../../lib/format";
  import type { Project, Tag, AttachedFile, TimeEntry } from "../../types";

  let projects = $derived(($page.props.projects as Project[]) || []);
  let tags = $derived(($page.props.tags as Tag[]) || []);
  let recentEntries = $derived(($page.props.recentEntries as TimeEntry[]) || []);

  let editingEntry = $state<TimeEntry | null>(null);
  let showDeleteModal = $state(false);
  let entryToDelete = $state<TimeEntry | null>(null);
  let editFileInput: HTMLInputElement | null = $state(null);

  let showFilters = $state(false);
  let filters = $state({
    search: "",
    projectId: "",
    dateRange: "this_week",
  });

  function getDateRange(range: string): {
    start: Date | null;
    end: Date | null;
  } {
    const now = new Date();

    const startOfDay = (d: Date) => {
      const x = new Date(d);
      x.setHours(0, 0, 0, 0);
      return x;
    };

    const endOfDay = (d: Date) => {
      const x = new Date(d);
      x.setHours(23, 59, 59, 999);
      return x;
    };

    switch (range) {
      case "today":
        return { start: startOfDay(now), end: endOfDay(now) };
      case "this_week": {
        const day = now.getDay();
        const diff = (day + 6) % 7;
        const start = new Date(now);
        start.setDate(now.getDate() - diff);
        const end = new Date(start);
        end.setDate(start.getDate() + 6);
        return { start: startOfDay(start), end: endOfDay(end) };
      }
      case "last_week": {
        const day = now.getDay();
        const diff = (day + 6) % 7;
        const startThisWeek = new Date(now);
        startThisWeek.setDate(now.getDate() - diff);
        const start = new Date(startThisWeek);
        start.setDate(startThisWeek.getDate() - 7);
        const end = new Date(start);
        end.setDate(start.getDate() + 6);
        return { start: startOfDay(start), end: endOfDay(end) };
      }
      case "this_month": {
        const start = new Date(now.getFullYear(), now.getMonth(), 1);
        const end = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        return { start: startOfDay(start), end: endOfDay(end) };
      }
      default:
        return { start: null, end: null };
    }
  }

  function getFilteredEntries(allEntries: TimeEntry[]) {
    const search = filters.search.trim().toLowerCase();
    const projectId = filters.projectId;
    const { start, end } = getDateRange(filters.dateRange);

    return allEntries.filter((entry) => {
      if (search) {
        const hay = (entry.description || "").toLowerCase();
        if (!hay.includes(search)) return false;
      }

      if (projectId) {
        if (!entry.project || entry.project.id.toString() !== projectId)
          return false;
      }

      if (start && end) {
        const startedAt = new Date(entry.start_at);
        if (startedAt < start || startedAt > end) return false;
      }

      return true;
    });
  }

  let filteredEntries = $derived(getFilteredEntries(recentEntries));

  let editForm = useForm({
    description: "",
    project_id: "" as string,
    tag_ids: [] as number[],
    billable: false,
    files: [] as File[],
  });

  function openDeleteModal(entry: TimeEntry) {
    entryToDelete = entry;
    showDeleteModal = true;
  }

  function closeDeleteModal() {
    showDeleteModal = false;
    entryToDelete = null;
  }

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  function confirmDeleteEntry() {
    if (!entryToDelete || !workspaceId) return;
    router.delete(routes.timeEntries.delete(workspaceId, entryToDelete.id), {
      preserveScroll: true,
    });
    closeDeleteModal();
  }

  function openEdit(entry: TimeEntry) {
    editingEntry = entry;
    $editForm.description = entry.description || "";
    $editForm.project_id = entry.project?.id?.toString() || "";
    $editForm.tag_ids = (entry.tags || []).map((t) => t.id);
    $editForm.billable = !!entry.billable;
    $editForm.files = [];
  }

  function closeEdit() {
    editingEntry = null;
    $editForm.reset();
  }

  function toggleTag(tagId: number) {
    if ($editForm.tag_ids.includes(tagId)) {
      $editForm.tag_ids = $editForm.tag_ids.filter((id) => id !== tagId);
    } else {
      $editForm.tag_ids = [...$editForm.tag_ids, tagId];
    }
  }

  function handleEditFileSelect(event: Event) {
    const target = event.target as HTMLInputElement;
    if (target.files) {
      const files = Array.from(target.files);
      const existingCount =
        (editingEntry?.files?.length || 0) + $editForm.files.length;
      if (existingCount + files.length > 3) {
        alert("You can only attach up to 3 files");
        target.value = "";
        return;
      }
      $editForm.files = [...$editForm.files, ...files].slice(
        0,
        3 - (editingEntry?.files?.length || 0),
      );
      target.value = "";
    }
  }

  function removeEditFile(index: number) {
    $editForm.files = $editForm.files.filter((_, i) => i !== index);
  }

  function deleteExistingFile(blobId: number) {
    if (!editingEntry || !workspaceId) return;
    router.delete(
      `${routes.timeEntries.update(workspaceId, editingEntry.id)}/remove_file?blob_id=${blobId}`,
      {
        preserveScroll: true,
        onSuccess: () => {
          // Update local state to remove the file from UI
          if (editingEntry) {
            editingEntry.files =
              editingEntry.files?.filter((f) => f.blob_id !== blobId) || [];
          }
        },
      },
    );
  }

  function saveEdit() {
    if (!editingEntry || !workspaceId) return;

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
      .patch(routes.timeEntries.update(workspaceId, editingEntry.id), {
        preserveScroll: true,
        onSuccess: () => {
          closeEdit();
        },
      });
  }
</script>

<TimerInput runningEntry={$page.props.runningEntry} {projects} {tags} />

<PageLayout title="Timer" variant="narrow" flash={$page.props.flash}>
  {#snippet headerActions()}
    <button
      onclick={() => (showFilters = !showFilters)}
      class="flex items-center gap-2 px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
    >
      <Filter class="w-4 h-4" />
      Filters
      {#if showFilters}
        <ChevronUp class="w-4 h-4" />
      {:else}
        <ChevronDown class="w-4 h-4" />
      {/if}
    </button>
  {/snippet}

  {#if showFilters}
    <div
      class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4 animate-slide-in mb-4"
    >
      <div
        class="flex flex-col md:flex-row items-stretch md:items-center gap-4"
      >
        <div class="flex-1 relative">
          <Search
            class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-muted"
          />
          <input
            type="text"
            placeholder="Search entries..."
            bind:value={filters.search}
            class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] pl-10 pr-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue transition-colors duration-150"
          />
        </div>
        <select
          bind:value={filters.projectId}
          class="bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
        >
          <option value="">All Projects</option>
          {#each projects as project}
            <option value={project.id}>{project.name}</option>
          {/each}
        </select>
        <select
          bind:value={filters.dateRange}
          class="bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
        >
          <option value="today">Today</option>
          <option value="this_week">This Week</option>
          <option value="last_week">Last Week</option>
          <option value="this_month">This Month</option>
        </select>
      </div>
    </div>
  {/if}

  <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
    <div
      class="p-4 border-b border-bg-tertiary flex items-center justify-between"
    >
      <h3 class="font-semibold text-lg">
        Time Entries ({filteredEntries.length})
      </h3>
    </div>

    {#if filteredEntries.length === 0}
      <div class="p-8 text-center text-fg-muted">
        <p>No time entries match your filters.</p>
      </div>
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each filteredEntries as entry}
          <div
            class="p-4 hover:bg-bg-tertiary/50 transition-colors duration-150"
          >
            <!-- Mobile layout -->
            <div class="flex flex-col gap-2 sm:hidden">
              <div class="flex items-start justify-between gap-2">
                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate">
                    {entry.description || "No description"}
                  </p>
                  {#if entry.project}
                    <div class="flex items-center gap-2 mt-1">
                      <span
                        class="w-3 h-3 rounded-full shrink-0"
                        style="background-color: {entry.project.color || '#b16286'}"
                      ></span>
                      <span class="text-sm text-fg-muted">{entry.project.name}</span>
                    </div>
                  {/if}
                </div>
                <div class="flex items-center gap-1 shrink-0">
                  <button
                    class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                    aria-label="Edit entry"
                    onclick={() => openEdit(entry)}
                  >
                    <Edit2 class="w-4 h-4" />
                  </button>
                  <button
                    class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                    aria-label="Delete entry"
                    onclick={() => openDeleteModal(entry)}
                  >
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </div>
              <div class="flex items-center justify-between text-sm">
                <div class="text-fg-muted">
                  <span>{formatShortDate(entry.start_at)}</span>
                  <span class="mx-1">·</span>
                  <span>{formatTime(entry.start_at)} - {entry.end_at ? formatTime(entry.end_at) : "now"}</span>
                </div>
                <div class="flex items-center gap-2">
                  {#if entry.billable}
                    <DollarSign class="w-4 h-4 text-bright-green" />
                  {/if}
                  <span class="font-tabular font-medium">{entry.formattedDuration}</span>
                </div>
              </div>
            </div>

            <!-- Desktop layout -->
            <div class="hidden sm:flex items-center gap-4">
              <div class="w-24 text-sm text-fg-muted shrink-0">
                <div>{formatShortDate(entry.start_at)}</div>
                <div>
                  {formatTime(entry.start_at)} - {entry.end_at
                    ? formatTime(entry.end_at)
                    : "now"}
                </div>
              </div>

              <div class="flex-1 min-w-0">
                <p class="font-medium truncate">
                  {entry.description || "No description"}
                </p>
                {#if entry.project}
                  <div class="flex items-center gap-2 mt-1">
                    <span
                      class="w-3 h-3 rounded-full"
                      style="background-color: {entry.project.color || '#b16286'}"
                    ></span>
                    <span class="text-sm text-fg-muted">{entry.project.name}</span>
                  </div>
                {/if}
              </div>

              {#if entry.billable}
                <DollarSign class="w-4 h-4 text-bright-green" />
              {/if}

              <div class="text-right min-w-20">
                <span class="font-tabular font-medium"
                  >{entry.formattedDuration}</span
                >
              </div>

              <div class="flex items-center gap-2">
                <button
                  class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                  aria-label="Edit entry"
                  onclick={() => openEdit(entry)}
                >
                  <Edit2 class="w-4 h-4" />
                </button>
                <button
                  class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                  aria-label="Delete entry"
                  onclick={() => openDeleteModal(entry)}
                >
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  {#if editingEntry}
    <div
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Edit time entry"
    >
      <div
        class="absolute inset-0 bg-black/50"
        onclick={closeEdit}
        aria-hidden="true"
      ></div>
      <div
        class="relative w-full max-w-lg bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
      >
        <div
          class="p-4 border-b border-bg-tertiary flex items-center justify-between"
        >
          <h3 class="font-semibold">Edit Entry</h3>
          <button
            type="button"
            class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
            onclick={closeEdit}
            aria-label="Close"
          >
            <X class="w-4 h-4" aria-hidden="true" />
          </button>
        </div>

        <div class="p-4 space-y-4">
          <div>
            <label
              for="edit-description"
              class="block text-sm font-medium text-fg-secondary mb-1"
              >Description</label
            >
            <input
              id="edit-description"
              type="text"
              bind:value={$editForm.description}
              class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label
                for="edit-project"
                class="block text-sm font-medium text-fg-secondary mb-1"
                >Project</label
              >
              <select
                id="edit-project"
                bind:value={$editForm.project_id}
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
              >
                <option value="">No project</option>
                {#each projects as project}
                  <option value={project.id.toString()}>{project.name}</option>
                {/each}
              </select>
            </div>

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
            <span class="block text-sm font-medium text-fg-secondary mb-2"
              >Tags</span
            >
            {#if tags.length === 0}
              <p class="text-sm text-fg-muted">No tags yet.</p>
            {:else}
              <div class="flex flex-wrap gap-2">
                {#each tags as tag}
                  <button
                    type="button"
                    class="px-3 py-1.5 rounded-[10px] border text-sm transition-colors duration-150 {$editForm.tag_ids.includes(
                      tag.id,
                    )
                      ? 'border-bright-green text-bright-green'
                      : 'border-bg-tertiary text-fg-muted hover:text-fg-primary'}"
                    aria-pressed={$editForm.tag_ids.includes(tag.id)}
                    onclick={() => toggleTag(tag.id)}
                  >
                    {tag.name}
                  </button>
                {/each}
              </div>
            {/if}
          </div>

          <div>
            <span class="block text-sm font-medium text-fg-secondary mb-2"
              >Attachments</span
            >
            <div class="space-y-2">
              {#if editingEntry?.files && editingEntry.files.length > 0}
                <div class="flex flex-wrap gap-2">
                  {#each editingEntry.files as file}
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

              {#if (editingEntry?.files?.length || 0) + $editForm.files.length < 3}
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
                    Add Files ({(editingEntry?.files?.length || 0) +
                      $editForm.files.length}/3)
                  </button>
                  <span class="text-xs text-fg-muted">Max 10MB each</span>
                </div>
              {/if}
            </div>
          </div>
        </div>

        <div
          class="p-4 border-t border-bg-tertiary flex items-center justify-end gap-2"
        >
          <button
            type="button"
            class="px-4 py-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
            onclick={closeEdit}
            disabled={$editForm.processing}
          >
            Cancel
          </button>
          <button
            type="button"
            class="flex items-center gap-2 px-4 py-2 bg-bright-blue hover:bg-accent-blue text-bg-primary rounded-[10px] transition-colors duration-150 font-medium disabled:opacity-50"
            onclick={saveEdit}
            disabled={$editForm.processing}
          >
            <Check class="w-4 h-4" aria-hidden="true" />
            {$editForm.processing ? "Saving..." : "Save"}
          </button>
        </div>
      </div>
    </div>
  {/if}

  <Modal
    bind:open={showDeleteModal}
    title="Delete Time Entry"
    onclose={closeDeleteModal}
  >
    <div class="space-y-4">
      <p class="text-fg-primary">
        Are you sure you want to delete this time entry?
      </p>
      {#if entryToDelete?.description}
        <p class="text-sm text-fg-muted italic">
          "{entryToDelete.description}"
        </p>
      {/if}
      <p class="text-sm text-fg-muted">This action cannot be undone.</p>
    </div>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <button
          type="button"
          class="px-4 py-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
          onclick={closeDeleteModal}
        >
          Cancel
        </button>
        <button
          type="button"
          class="px-4 py-2 bg-bright-red hover:bg-accent-red text-bg-primary rounded-[10px] transition-colors duration-150 font-medium"
          onclick={confirmDeleteEntry}
        >
          Delete Entry
        </button>
      </div>
    {/snippet}
  </Modal>
</PageLayout>
