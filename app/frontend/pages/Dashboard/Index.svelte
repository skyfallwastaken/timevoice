<script lang="ts">
  import TimerInput from "../../components/TimerInput.svelte";
  import Flash from "../../components/Flash.svelte";
  import { page, router } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import { SvelteSet } from "svelte/reactivity";
  import { routes } from "../../lib/routes";
  import SelectInput from "../../components/SelectInput.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import TimeEntryEditModal from "../../components/TimeEntryEditModal.svelte";
  import TimeEntryBulkEditModal from "../../components/TimeEntryBulkEditModal.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
  import {
    Pencil,
    Trash2,
    DollarSign,
    Search,
    Play,
    Copy,
    EllipsisVertical,
    Paperclip,
    X,
    ListChecks,
  } from "lucide-svelte";
  import { formatDuration, toDateString } from "../../lib/format";
  import type { Project, Tag, TimeEntry } from "../../types";

  let projects = $derived(($page.props.projects as Project[]) || []);
  let tags = $derived(($page.props.tags as Tag[]) || []);
  let recentEntries = $derived(
    ($page.props.recentEntries as TimeEntry[]) || [],
  );
  let totals = $derived(
    ($page.props.totals as { today: number; week: number }) || {
      today: 0,
      week: 0,
    },
  );
  let hasEntries = $derived(!!$page.props.hasEntries);
  let entryLimit = $derived(($page.props.entryLimit as number) || 0);

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  type Filters = { range: string; project_id: string; q: string };

  const initialFilters = ($page.props.filters as Partial<Filters>) || {};
  let filters = $state<Filters>({
    range: initialFilters.range ?? "this_week",
    project_id: initialFilters.project_id ?? "",
    q: initialFilters.q ?? "",
  });

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  function applyFilters({ debounce = false } = {}) {
    clearTimeout(searchTimer);
    const run = () =>
      router.get(
        routes.dashboard.index(workspaceId),
        {
          range: filters.range,
          project_id: filters.project_id || undefined,
          q: filters.q.trim() || undefined,
        },
        { preserveState: true, preserveScroll: true, replace: true },
      );
    if (debounce) {
      searchTimer = setTimeout(run, 300);
    } else {
      run();
    }
  }

  const rangeLabels: Record<string, string> = {
    today: "today",
    this_week: "this week",
    last_week: "last week",
    this_month: "this month",
    all: "",
  };

  // Entries arrive newest first; group them by the local day they started.
  let groups = $derived.by(() => {
    const byDay = new Map<string, TimeEntry[]>();
    for (const entry of recentEntries) {
      const key = toDateString(new Date(entry.start_at));
      byDay.set(key, [...(byDay.get(key) ?? []), entry]);
    }
    return [...byDay].map(([key, entries]) => ({
      key,
      entries,
      seconds: entries.reduce((sum, e) => sum + (e.duration_seconds ?? 0), 0),
    }));
  });

  function dayLabel(key: string) {
    const today = new Date();
    const yesterday = new Date();
    yesterday.setDate(today.getDate() - 1);
    if (key === toDateString(today)) return "Today";
    if (key === toDateString(yesterday)) return "Yesterday";
    const date = new Date(`${key}T00:00:00`);
    return date.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      ...(date.getFullYear() !== today.getFullYear() && { year: "numeric" }),
    });
  }

  const clockTime = (iso: string) =>
    new Date(iso).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });

  // Selection
  const selected = new SvelteSet<number>();
  let anchorId: number | null = null;
  let shiftHeld = false;
  let orderedIds = $derived(recentEntries.map((e) => e.id));
  let selecting = $derived(selected.size > 0);

  $effect(() => {
    const visible = new Set(orderedIds);
    untrack(() => {
      for (const id of [...selected]) if (!visible.has(id)) selected.delete(id);
    });
  });

  function setEntrySelected(id: number, value: boolean, range = false) {
    const from = anchorId === null ? -1 : orderedIds.indexOf(anchorId);
    const to = orderedIds.indexOf(id);
    const ids =
      range && from !== -1
        ? orderedIds.slice(Math.min(from, to), Math.max(from, to) + 1)
        : [id];
    for (const each of ids) {
      if (value) selected.add(each);
      else selected.delete(each);
    }
    anchorId = id;
  }

  function setGroupSelected(entries: TimeEntry[], value: boolean) {
    for (const entry of entries) {
      if (value) selected.add(entry.id);
      else selected.delete(entry.id);
    }
  }

  function clearSelection() {
    selected.clear();
    anchorId = null;
  }

  function handleRowClick(event: MouseEvent, entry: TimeEntry) {
    const target = event.target as HTMLElement;
    if (target.closest("button, a, input, [role=menuitem]")) return;
    if (selecting) {
      setEntrySelected(entry.id, !selected.has(entry.id), event.shiftKey);
    } else {
      openEdit(entry);
    }
  }

  // Single-entry actions
  let editingEntry = $state<TimeEntry | null>(null);
  let entryToDelete = $state<TimeEntry | null>(null);
  let showDeleteModal = $state(false);
  let showBulkEdit = $state(false);
  let showBulkDelete = $state(false);

  function openEdit(entry: TimeEntry) {
    editingEntry = entry;
  }

  function closeEdit() {
    editingEntry = null;
  }

  function openDeleteModal(entry: TimeEntry) {
    entryToDelete = entry;
    showDeleteModal = true;
  }

  function closeDeleteModal() {
    showDeleteModal = false;
    entryToDelete = null;
  }

  function confirmDeleteEntry() {
    if (!entryToDelete || !workspaceId) return;
    router.delete(routes.timeEntries.delete(workspaceId, entryToDelete.id), {
      preserveScroll: true,
    });
    if (editingEntry?.id === entryToDelete.id) closeEdit();
    closeDeleteModal();
  }

  function createFrom(
    entry: TimeEntry,
    times: { start_at: string; end_at?: string },
  ) {
    router.post(
      routes.timeEntries.create(workspaceId),
      {
        time_entry: {
          description: entry.description,
          project_id: entry.project?.id ?? null,
          billable: entry.billable,
          tag_ids: entry.tags.map((t) => t.id),
          ...times,
        },
      },
      { preserveScroll: true },
    );
  }

  const continueEntry = (entry: TimeEntry) =>
    createFrom(entry, { start_at: new Date().toISOString() });

  const duplicateEntry = (entry: TimeEntry) =>
    createFrom(entry, { start_at: entry.start_at, end_at: entry.end_at! });

  function confirmBulkDelete() {
    router.delete(routes.timeEntries.bulkDestroy(workspaceId), {
      data: { ids: [...selected] },
      preserveScroll: true,
      onSuccess: clearSelection,
    });
    showBulkDelete = false;
  }

  function handleKeydown(event: KeyboardEvent) {
    if (
      event.key === "Escape" &&
      selecting &&
      !editingEntry &&
      !showDeleteModal &&
      !showBulkEdit &&
      !showBulkDelete
    ) {
      clearSelection();
    }
  }

  const checkboxReveal =
    "opacity-0 group-hover:opacity-100 focus-visible:opacity-100 [@media(hover:none)]:opacity-100";
</script>

<svelte:window onkeydown={handleKeydown} />

<TimerInput runningEntry={$page.props.runningEntry} {projects} {tags} />

<div class="flex-1 overflow-auto">
  <div class="max-w-5xl mx-auto px-4 sm:px-6 pb-8">
    <div
      class="sticky top-0 z-10 bg-bg-primary pt-4 sm:pt-6 pb-3"
      role="toolbar"
      aria-label={selecting ? "Selected entries" : "Filter entries"}
    >
      {#if selecting}
        <div
          class="h-10 flex items-center gap-1 px-2 rounded-[10px] bg-bg-secondary border border-bright-purple/40"
        >
          <span class="px-2 font-medium" aria-live="polite">
            {selected.size}
            {selected.size === 1 ? "item" : "items"} selected
          </span>
          <span class="w-px h-5 bg-bg-tertiary mx-1" aria-hidden="true"></span>
          <button
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm hover:bg-bg-tertiary transition-colors"
            onclick={() => (showBulkEdit = true)}
          >
            <Pencil class="w-4 h-4" aria-hidden="true" /> Edit
          </button>
          <button
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm text-bright-red hover:bg-bright-red/10 transition-colors"
            onclick={() => (showBulkDelete = true)}
          >
            <Trash2 class="w-4 h-4" aria-hidden="true" /> Delete
          </button>
          <button
            type="button"
            class="ml-auto p-1.5 rounded-lg text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors"
            aria-label="Clear selection"
            title="Clear selection (Esc)"
            onclick={clearSelection}
          >
            <X class="w-4 h-4" aria-hidden="true" />
          </button>
        </div>
      {:else}
        <div class="flex flex-wrap items-center gap-2">
          <label class="sr-only" for="filter-date">Date range</label>
          <div class="w-36">
            <SelectInput
              id="filter-date"
              bind:value={filters.range}
              onchange={() => applyFilters()}
              class="h-10 py-0 bg-bg-secondary"
            >
              <option value="today">Today</option>
              <option value="this_week">This week</option>
              <option value="last_week">Last week</option>
              <option value="this_month">This month</option>
              <option value="all">All dates</option>
            </SelectInput>
          </div>
          <label class="sr-only" for="filter-project">Project</label>
          <div class="w-44">
            <SelectInput
              id="filter-project"
              bind:value={filters.project_id}
              onchange={() => applyFilters()}
              class="h-10 py-0 bg-bg-secondary"
            >
              <option value="">All projects</option>
              {#each projects as project}
                <option value={project.id}>{project.name}</option>
              {/each}
            </SelectInput>
          </div>
          <div class="relative flex-1 min-w-40">
            <Search
              class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-muted"
              aria-hidden="true"
            />
            <label class="sr-only" for="entry-search">Search entries</label>
            <input
              id="entry-search"
              bind:value={filters.q}
              oninput={() => applyFilters({ debounce: true })}
              placeholder="Search entries..."
              class="w-full h-10 pl-9 pr-3 rounded-[10px] bg-bg-secondary border border-bg-tertiary text-fg-primary placeholder:text-fg-dim outline-none focus:border-bright-blue transition-colors"
            />
          </div>
        </div>
      {/if}
    </div>

    <div class="flex gap-6 text-xs uppercase tracking-wide text-fg-muted mb-4">
      <span
        >Today <span
          class="ml-2 text-sm normal-case tracking-normal font-tabular text-fg-primary"
          >{formatDuration(totals.today)}</span
        ></span
      >
      <span
        >Week total <span
          class="ml-2 text-sm normal-case tracking-normal font-tabular text-fg-primary"
          >{formatDuration(totals.week)}</span
        ></span
      >
    </div>

    <Flash flash={$page.props.flash} />

    {#if !hasEntries}
      <div
        class="p-8 text-center text-fg-muted bg-bg-secondary border border-bg-tertiary rounded-[10px]"
      >
        <p class="text-fg-primary font-medium">No time tracked yet</p>
        <p class="mt-1">
          Type what you're working on above and press Enter to start the timer.
        </p>
      </div>
    {:else if recentEntries.length === 0}
      <div
        class="p-8 text-center text-fg-muted bg-bg-secondary border border-bg-tertiary rounded-[10px]"
      >
        {#if filters.q || filters.project_id}
          <p>No time entries match your filters.</p>
        {:else}
          <p>No time entries {rangeLabels[filters.range]}.</p>
        {/if}
      </div>
    {:else}
      <div class="space-y-4">
        {#each groups as group (group.key)}
          {@const groupSelected = group.entries.filter((e) =>
            selected.has(e.id),
          ).length}
          <section
            class="bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
            aria-label={dayLabel(group.key)}
          >
            <header
              class="group flex items-center gap-3 px-4 h-11 border-b border-bg-tertiary"
            >
              <Checkbox
                class="{groupSelected > 0 ? '' : checkboxReveal} {selecting
                  ? 'opacity-100'
                  : ''}"
                aria-label="Select all entries for {dayLabel(group.key)}"
                checked={groupSelected === group.entries.length}
                indeterminate={groupSelected > 0 &&
                  groupSelected < group.entries.length}
                onCheckedChange={(value) =>
                  setGroupSelected(group.entries, value)}
              />
              <h3 class="font-semibold">{dayLabel(group.key)}</h3>
              <span class="ml-auto font-tabular text-fg-muted text-sm"
                >{formatDuration(group.seconds)}</span
              >
              <span class="w-0 sm:w-14" aria-hidden="true"></span>
            </header>

            <ul class="divide-y divide-bg-tertiary">
              {#each group.entries as entry (entry.id)}
                {@const isSelected = selected.has(entry.id)}
                <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_noninteractive_element_interactions -->
                <li
                  class="group flex items-center gap-3 px-4 py-2.5 cursor-pointer transition-colors duration-150 {isSelected
                    ? 'bg-bright-purple/10'
                    : 'hover:bg-bg-tertiary/40'}"
                  onclick={(e) => handleRowClick(e, entry)}
                >
                  <Checkbox
                    class={isSelected || selecting ? "" : checkboxReveal}
                    aria-label="Select {entry.description || 'entry'}"
                    bind:checked={
                      () => isSelected,
                      (value) => setEntrySelected(entry.id, value, shiftHeld)
                    }
                    onpointerdown={(e) => (shiftHeld = e.shiftKey)}
                    onkeydown={(e) => (shiftHeld = e.shiftKey)}
                  />

                  <div
                    class="flex-1 min-w-0 flex flex-col sm:flex-row sm:items-center gap-x-3 gap-y-0.5"
                  >
                    <button
                      type="button"
                      class="min-w-0 truncate text-left {entry.description
                        ? 'text-fg-primary'
                        : 'text-fg-dim'}"
                      onclick={(e) => {
                        if (selecting) handleRowClick(e, entry);
                        else openEdit(entry);
                      }}
                    >
                      {entry.description || "Add description"}
                    </button>
                    {#if entry.project}
                      <span
                        class="flex items-center gap-1.5 text-sm min-w-0 shrink-0"
                        style="color: {entry.project.color}"
                      >
                        <span
                          class="w-2 h-2 rounded-full shrink-0"
                          style="background-color: {entry.project.color}"
                          aria-hidden="true"
                        ></span>
                        <span class="truncate">{entry.project.name}</span>
                      </span>
                    {/if}
                    {#if entry.tags.length > 0}
                      <span class="hidden md:flex items-center gap-1 shrink-0">
                        {#each entry.tags as tag (tag.id)}
                          <span
                            class="px-1.5 py-0.5 rounded-md bg-bg-tertiary text-xs text-fg-secondary"
                            >{tag.name}</span
                          >
                        {/each}
                      </span>
                    {/if}
                  </div>

                  {#if entry.files?.length}
                    <Paperclip
                      class="hidden sm:block w-4 h-4 text-fg-muted shrink-0"
                      aria-label="{entry.files.length} attachments"
                    />
                  {/if}
                  <DollarSign
                    class="hidden sm:block w-4 h-4 shrink-0 {entry.billable
                      ? 'text-bright-green'
                      : 'text-fg-dim/40'}"
                    aria-label={entry.billable ? "Billable" : "Non-billable"}
                  />
                  <span
                    class="hidden sm:block w-40 text-right text-sm text-fg-muted font-tabular whitespace-nowrap"
                  >
                    {clockTime(entry.start_at)} – {entry.end_at
                      ? clockTime(entry.end_at)
                      : "now"}
                  </span>
                  <span
                    class="font-tabular font-medium w-[4.5rem] text-right shrink-0"
                    >{formatDuration(entry.duration_seconds ?? 0)}</span
                  >

                  <div class="flex items-center shrink-0">
                    <IconButton
                      size="sm"
                      class="hidden sm:inline-flex opacity-0 group-hover:opacity-100 focus-visible:opacity-100"
                      aria-label="Continue {entry.description || 'entry'}"
                      title="Continue this entry"
                      onclick={() => continueEntry(entry)}
                    >
                      <Play class="w-4 h-4 fill-current" aria-hidden="true" />
                    </IconButton>
                    <DropdownMenu.Root>
                      <DropdownMenu.Trigger>
                        {#snippet child({ props })}
                          <IconButton
                            {...props}
                            size="sm"
                            class="sm:opacity-0 sm:group-hover:opacity-100 focus-visible:opacity-100 data-[state=open]:opacity-100 data-[state=open]:bg-bg-tertiary"
                            aria-label="More actions"
                          >
                            <EllipsisVertical
                              class="w-4 h-4"
                              aria-hidden="true"
                            />
                          </IconButton>
                        {/snippet}
                      </DropdownMenu.Trigger>
                      <DropdownMenu.Content align="end" class="min-w-40">
                        <DropdownMenu.Item
                          class="px-3 py-2 gap-2"
                          onSelect={() => openEdit(entry)}
                        >
                          <Pencil aria-hidden="true" /> Edit
                        </DropdownMenu.Item>
                        <DropdownMenu.Item
                          class="px-3 py-2 gap-2"
                          onSelect={() => continueEntry(entry)}
                        >
                          <Play aria-hidden="true" /> Continue
                        </DropdownMenu.Item>
                        <DropdownMenu.Item
                          class="px-3 py-2 gap-2"
                          onSelect={() => duplicateEntry(entry)}
                        >
                          <Copy aria-hidden="true" /> Duplicate
                        </DropdownMenu.Item>
                        <DropdownMenu.Item
                          class="px-3 py-2 gap-2"
                          onSelect={() => setEntrySelected(entry.id, true)}
                        >
                          <ListChecks aria-hidden="true" /> Select
                        </DropdownMenu.Item>
                        <DropdownMenu.Separator />
                        <DropdownMenu.Item
                          variant="destructive"
                          class="px-3 py-2 gap-2"
                          onSelect={() => openDeleteModal(entry)}
                        >
                          <Trash2 aria-hidden="true" /> Delete
                        </DropdownMenu.Item>
                      </DropdownMenu.Content>
                    </DropdownMenu.Root>
                  </div>
                </li>
              {/each}
            </ul>
          </section>
        {/each}
      </div>
      {#if recentEntries.length >= entryLimit}
        <p class="mt-4 text-center text-sm text-fg-muted">
          Showing the latest {entryLimit} entries. Narrow the date range to see older
          ones.
        </p>
      {/if}
    {/if}
  </div>
</div>

<TimeEntryEditModal
  entry={editingEntry}
  {projects}
  {tags}
  open={editingEntry !== null}
  onClose={closeEdit}
  onDelete={openDeleteModal}
/>

<TimeEntryBulkEditModal
  ids={[...selected]}
  {projects}
  {tags}
  open={showBulkEdit}
  onClose={() => (showBulkEdit = false)}
  onSaved={() => {
    showBulkEdit = false;
    clearSelection();
  }}
/>

<ConfirmDeleteModal
  bind:open={showDeleteModal}
  title="Delete Time Entry"
  itemName="this time entry"
  warningMessage="This action cannot be undone."
  onConfirm={confirmDeleteEntry}
  onClose={closeDeleteModal}
>
  {#snippet details()}
    {#if entryToDelete?.description}
      <p class="text-sm text-fg-muted italic">
        "{entryToDelete.description}"
      </p>
    {/if}
  {/snippet}
</ConfirmDeleteModal>

<ConfirmDeleteModal
  bind:open={showBulkDelete}
  title="Delete Time Entries"
  itemName="{selected.size} time {selected.size === 1 ? 'entry' : 'entries'}"
  warningMessage="This action cannot be undone."
  confirmLabel="Delete {selected.size} {selected.size === 1
    ? 'entry'
    : 'entries'}"
  onConfirm={confirmBulkDelete}
  onClose={() => (showBulkDelete = false)}
/>
