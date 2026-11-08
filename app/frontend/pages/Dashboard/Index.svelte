<script lang="ts">
  import TimerInput from "../../components/TimerInput.svelte";
  import WeekCalendar from "../../components/WeekCalendar.svelte";
  import { page, router, Link } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import { SvelteSet } from "svelte/reactivity";
  import { routes } from "../../lib/routes";
  import EmptyState from "../../components/EmptyState.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import TimeEntryEditor from "../../components/TimeEntryEditor.svelte";
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
    ChevronLeft,
    ChevronRight,
    ChevronDown,
    CalendarDays,
    List,
    Clock,
    SearchX,
  } from "@lucide/svelte";
  import {
    dateFormatter,
    formatDuration,
    formatHours,
    parseLocalDate,
    toDateString,
  } from "../../lib/format";
  import {
    draftFromEntry,
    type TimeEntryDraft,
  } from "../../lib/time-entry-form";
  import type { Snippet } from "svelte";
  import type { Project, RecentDescription, Tag, TimeEntry } from "../../types";

  let projects = $derived((page.props.projects as Project[]) || []);
  let tags = $derived((page.props.tags as Tag[]) || []);
  let recentEntries = $derived((page.props.recentEntries as TimeEntry[]) || []);
  let view = $derived((page.props.view as "list" | "calendar") || "list");
  let calendarEntries = $derived((page.props.entries as TimeEntry[]) || []);
  let weekStart = $derived((page.props.weekStart as string) || "");
  let hasEntries = $derived(!!page.props.hasEntries);
  let entryLimit = $derived((page.props.entryLimit as number) || 0);
  let recentDescriptions = $derived(
    (page.props.recentDescriptions as RecentDescription[]) || [],
  );

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);

  // `date` is the first day of the period the list shows; empty means the
  // range preset relative to today.
  type Filters = { range: string; date: string; project_id: string; q: string };

  const initialFilters = (page.props.filters as Partial<Filters>) || {};
  let filters = $state<Filters>({
    range: initialFilters.range ?? "this_week",
    date: initialFilters.date ?? "",
    project_id: initialFilters.project_id ?? "",
    q: initialFilters.q ?? "",
  });

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  // A pending search would otherwise navigate back here after leaving.
  $effect(() => () => clearTimeout(searchTimer));
  function applyFilters({ debounce = false } = {}) {
    clearTimeout(searchTimer);
    const run = () =>
      router.get(
        routes.dashboard.index(workspaceId),
        {
          range: filters.range,
          date: filters.date || undefined,
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

  function visit(params: Record<string, string | undefined>) {
    router.get(routes.dashboard.index(workspaceId), params, {
      preserveState: true,
      preserveScroll: true,
    });
  }

  const switchView = (next: "list" | "calendar") =>
    next !== view && visit({ view: next });

  function shiftWeek(weeks: number) {
    const start = parseLocalDate(weekStart);
    start.setDate(start.getDate() + weeks * 7);
    visit({ view: "calendar", week_start: toDateString(start) });
  }

  const DAY_COUNT_KEY = "calendar-day-count";
  let dayCount = $state(
    typeof localStorage !== "undefined" &&
      localStorage.getItem(DAY_COUNT_KEY) === "5"
      ? 5
      : 7,
  );
  function setDayCount(count: number) {
    dayCount = count;
    localStorage.setItem(DAY_COUNT_KEY, String(count));
  }

  // ISO week number, as in "This week · W45".
  function isoWeek(date: Date) {
    const d = new Date(
      Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()),
    );
    d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  }

  // Where each range preset starts, relative to today.
  function presetStart(range: string) {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    if (range === "this_month") date.setDate(1);
    if (range === "this_week" || range === "last_week")
      date.setDate(date.getDate() - ((date.getDay() + 6) % 7));
    if (range === "last_week") date.setDate(date.getDate() - 7);
    return date;
  }

  function weekLabelFor(start: Date, days: number) {
    const weeksAway = Math.round(
      (start.getTime() - presetStart("this_week").getTime()) / (7 * 86400000),
    );
    if (weeksAway === 0) return "This week";
    if (weeksAway === -1) return "Last week";
    const end = new Date(start);
    end.setDate(start.getDate() + days - 1);
    const short = (date: Date) =>
      date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
    return `${short(start)} – ${short(end)}`;
  }

  let weekLabel = $derived(
    weekStart ? weekLabelFor(parseLocalDate(weekStart), dayCount) : "",
  );

  // The list's period: a day, week or month the arrows step through.
  const rangePresets = [
    { value: "today", label: "Today" },
    { value: "this_week", label: "This week" },
    { value: "last_week", label: "Last week" },
    { value: "this_month", label: "This month" },
    { value: "all", label: "All dates" },
  ];
  const periodKindOf = (range: string) =>
    range === "today"
      ? "day"
      : range === "this_month"
        ? "month"
        : range === "all"
          ? null
          : "week";
  let periodKind = $derived(periodKindOf(filters.range));
  let periodStart = $derived(
    filters.date ? parseLocalDate(filters.date) : presetStart(filters.range),
  );
  let periodLabel = $derived.by(() => {
    if (periodKind === "day") return dayLabel(toDateString(periodStart));
    if (periodKind === "week") return weekLabelFor(periodStart, 7);
    if (periodKind === "month") {
      const thisMonth = presetStart("this_month");
      const monthsAway =
        (periodStart.getFullYear() - thisMonth.getFullYear()) * 12 +
        periodStart.getMonth() -
        thisMonth.getMonth();
      if (monthsAway === 0) return "This month";
      if (monthsAway === -1) return "Last month";
      return periodStart.toLocaleDateString("en-US", {
        month: "long",
        year: "numeric",
      });
    }
    return "All dates";
  });
  // The preset the period matches, if any, so the menu can check it.
  let activePreset = $derived(
    rangePresets.find(
      ({ value }) =>
        periodKindOf(value) === periodKind &&
        (!periodKind || presetStart(value).getTime() === periodStart.getTime()),
    )?.value ?? "",
  );

  function selectPreset(range: string) {
    filters.range = range;
    filters.date = "";
    applyFilters();
  }

  function shiftPeriod(step: number) {
    if (!periodKind) return;
    const next = new Date(periodStart);
    if (periodKind === "day") next.setDate(next.getDate() + step);
    if (periodKind === "week") next.setDate(next.getDate() + step * 7);
    if (periodKind === "month") next.setMonth(next.getMonth() + step);
    filters.date = toDateString(next);
    applyFilters();
  }

  function clearFilters() {
    filters.q = "";
    filters.project_id = "";
    applyFilters();
  }

  // "this week", "yesterday", "for Oct 26 – Nov 1"; empty for all dates.
  let periodPhrase = $derived(
    !periodKind
      ? ""
      : /^(Today|Yesterday|This|Last)/.test(periodLabel)
        ? periodLabel.toLowerCase()
        : `for ${periodLabel}`,
  );

  let filterProject = $derived(
    projects.find((p) => String(p.id) === String(filters.project_id)),
  );

  // What the Logged bar sums: the visible calendar days, or the listed entries.
  let loggedEntries = $derived.by(() => {
    if (view === "list") return recentEntries;
    const end = parseLocalDate(weekStart);
    end.setDate(end.getDate() + dayCount);
    return calendarEntries.filter((e) => new Date(e.start_at) < end);
  });

  let loggedByProject = $derived.by(() => {
    const byProject = new Map<
      string,
      { key: string; name: string; color: string | null; seconds: number }
    >();
    for (const entry of loggedEntries) {
      const key = String(entry.project?.id ?? "none");
      const row = byProject.get(key) ?? {
        key,
        name: entry.project?.name ?? "No project",
        color: entry.project?.color ?? null,
        seconds: 0,
      };
      row.seconds += entry.duration_seconds ?? 0;
      byProject.set(key, row);
    }
    return [...byProject.values()].sort((a, b) => b.seconds - a.seconds);
  });
  let loggedTotal = $derived(
    loggedByProject.reduce((sum, row) => sum + row.seconds, 0),
  );

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
    const date = parseLocalDate(key);
    return date.getFullYear() !== today.getFullYear()
      ? dayInOtherYear(date)
      : dayInThisYear(date);
  }
  const dayInThisYear = dateFormatter({
    weekday: "short",
    month: "short",
    day: "numeric",
  });
  const dayInOtherYear = dateFormatter({
    weekday: "short",
    month: "short",
    day: "numeric",
    year: "numeric",
  });

  const clock = dateFormatter({ hour: "numeric", minute: "2-digit" });
  const clockTime = (iso: string) => clock(new Date(iso));

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

  // Single-entry actions. Closing a dialog keeps its entry so the dialog still
  // shows it while fading out.
  let editingId = $state<number | null>(null);
  let editingEntry = $derived(
    recentEntries.find((e) => e.id === editingId) ?? null,
  );
  let editDraft = $state<TimeEntryDraft | null>(null);
  let showEdit = $state(false);
  let entryToDelete = $state<TimeEntry | null>(null);
  let showDeleteModal = $state(false);
  let showBulkEdit = $state(false);
  let showBulkDelete = $state(false);

  function openEdit(entry: TimeEntry) {
    editingId = entry.id;
    editDraft = draftFromEntry(entry);
    showEdit = true;
  }

  function closeEdit() {
    showEdit = false;
  }

  function openDeleteModal(entry: TimeEntry) {
    entryToDelete = entry;
    showDeleteModal = true;
  }

  function closeDeleteModal() {
    showDeleteModal = false;
  }

  // Drops entries from both views at once; Inertia restores them if the delete fails.
  const withoutEntries =
    (ids: number[]) =>
    (props: { recentEntries?: TimeEntry[]; entries?: TimeEntry[] }) => ({
      recentEntries: props.recentEntries?.filter((e) => !ids.includes(e.id)),
      entries: props.entries?.filter((e) => !ids.includes(e.id)),
    });

  function confirmDeleteEntry() {
    if (!entryToDelete || !workspaceId) return;
    router
      .optimistic(withoutEntries([entryToDelete.id]))
      .delete(routes.timeEntries.delete(workspaceId, entryToDelete.id), {
        preserveScroll: true,
      });
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
    const ids = [...selected];
    router
      .optimistic(withoutEntries(ids))
      .delete(routes.timeEntries.bulkDestroy(workspaceId), {
        data: { ids },
        preserveScroll: true,
        onSuccess: clearSelection,
      });
    showBulkDelete = false;
  }

  function handleKeydown(event: KeyboardEvent) {
    if (
      event.key === "Escape" &&
      selecting &&
      !showEdit &&
      !showDeleteModal &&
      !showBulkEdit &&
      !showBulkDelete
    ) {
      clearSelection();
    }
  }

  const stepperLabel =
    "flex flex-1 @3xl:flex-none items-center justify-center gap-2 h-full @3xl:w-52 px-3 border-x border-bg-tertiary text-base md:text-sm font-medium font-tabular hover:bg-bg-tertiary data-[state=open]:bg-bg-tertiary transition-colors";
  const toolbarButton =
    "inline-flex items-center justify-between gap-1.5 h-8 px-3 rounded-lg border border-bg-tertiary bg-bg-primary text-base md:text-sm font-medium hover:bg-bg-tertiary data-[state=open]:bg-bg-tertiary transition-colors";

  const checkboxReveal =
    "opacity-0 group-hover:opacity-100 focus-visible:opacity-100 [@media(hover:none)]:opacity-100";
</script>

<svelte:window onkeydown={handleKeydown} />

{#snippet stepper(
  unit: string,
  shift: (step: number) => void,
  label: Snippet,
  disabled = false,
)}
  <div
    class="flex items-center w-full @3xl:w-auto h-8 rounded-lg border border-bg-tertiary bg-bg-primary"
  >
    <button
      type="button"
      class="grid place-items-center w-8 h-full rounded-l-[7px] text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors disabled:opacity-40 disabled:pointer-events-none"
      aria-label="Previous {unit}"
      {disabled}
      onclick={() => shift(-1)}
    >
      <ChevronLeft class="size-4" aria-hidden="true" />
    </button>
    {@render label()}
    <button
      type="button"
      class="grid place-items-center w-8 h-full rounded-r-[7px] text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors disabled:opacity-40 disabled:pointer-events-none"
      aria-label="Next {unit}"
      {disabled}
      onclick={() => shift(1)}
    >
      <ChevronRight class="size-4" aria-hidden="true" />
    </button>
  </div>
{/snippet}

{#snippet calendarWeek()}
  <button
    type="button"
    class={stepperLabel}
    title="Go to this week"
    onclick={() => visit({ view: "calendar" })}
  >
    <CalendarDays class="size-4 text-fg-muted" aria-hidden="true" />
    {weekLabel}
    <span class="text-fg-muted font-normal"
      >· W{isoWeek(parseLocalDate(weekStart))}</span
    >
  </button>
{/snippet}

{#snippet listPeriod()}
  <DropdownMenu.Root>
    <DropdownMenu.Trigger>
      {#snippet child({ props })}
        <button
          {...props}
          id="filter-date"
          type="button"
          class={stepperLabel}
          aria-label="Date range: {periodLabel}"
        >
          <CalendarDays class="size-4 text-fg-muted" aria-hidden="true" />
          <span class="truncate">{periodLabel}</span>
          {#if periodKind === "week"}
            <span class="text-fg-muted font-normal shrink-0"
              >· W{isoWeek(periodStart)}</span
            >
          {/if}
          <ChevronDown
            class="size-4 text-fg-muted shrink-0 ml-auto"
            aria-hidden="true"
          />
        </button>
      {/snippet}
    </DropdownMenu.Trigger>
    <DropdownMenu.Content align="center" class="min-w-44">
      <DropdownMenu.RadioGroup
        value={activePreset}
        onValueChange={selectPreset}
      >
        {#each rangePresets as preset (preset.value)}
          <DropdownMenu.RadioItem
            value={preset.value}
            closeOnSelect
            class="px-2 py-1.5 rounded-[5px]"
            >{preset.label}</DropdownMenu.RadioItem
          >
        {/each}
      </DropdownMenu.RadioGroup>
    </DropdownMenu.Content>
  </DropdownMenu.Root>
{/snippet}

<TimerInput
  runningEntry={page.props.runningEntry}
  {projects}
  {tags}
  {recentDescriptions}
/>

<div class="@container shrink-0 bg-bg-secondary border-b border-bg-tertiary">
  <div
    class="flex flex-wrap items-center gap-2 px-4 md:px-6 py-2"
    role="toolbar"
    aria-label={view === "calendar"
      ? "Calendar"
      : selecting
        ? "Selected entries"
        : "Filter entries"}
  >
    {#if view === "calendar"}
      {@render stepper("week", shiftWeek, calendarWeek)}
    {:else}
      <div class="contents @3xl:flex @3xl:flex-1 @3xl:items-center @3xl:gap-2">
        {#if selecting}
          <div
            class="h-8 basis-full @3xl:flex-1 flex items-center gap-1 px-1 rounded-lg bg-bg-primary border border-bright-purple/40"
          >
            <span
              class="px-2 @max-sm:px-1 text-sm font-medium whitespace-nowrap"
              aria-live="polite"
            >
              {selected.size}
              <span class="@max-sm:hidden"
                >{selected.size === 1 ? "item" : "items"}</span
              > selected
            </span>
            <span class="w-px h-5 bg-bg-tertiary mx-1" aria-hidden="true"
            ></span>
            <button
              type="button"
              class="inline-flex items-center gap-1.5 h-6 px-2 rounded-[5px] text-sm hover:bg-bg-tertiary transition-colors"
              onclick={() => (showBulkEdit = true)}
            >
              <Pencil class="w-4 h-4" aria-hidden="true" /> Edit
            </button>
            <button
              type="button"
              class="inline-flex items-center gap-1.5 h-6 px-2 rounded-[5px] text-sm text-bright-red hover:bg-bright-red/10 transition-colors"
              onclick={() => (showBulkDelete = true)}
            >
              <Trash2 class="w-4 h-4" aria-hidden="true" /> Delete
            </button>
            <button
              type="button"
              class="ml-auto grid place-items-center size-6 rounded-[5px] text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors"
              aria-label="Clear selection"
              title="Clear selection (Esc)"
              onclick={clearSelection}
            >
              <X class="w-4 h-4" aria-hidden="true" />
            </button>
          </div>
        {:else}
          <div class="basis-full @3xl:basis-auto">
            {@render stepper(
              periodKind ?? "period",
              shiftPeriod,
              listPeriod,
              !periodKind,
            )}
          </div>
          <div class="grow basis-[calc(50%-0.5rem)] @3xl:grow-0 @3xl:basis-44">
            <DropdownMenu.Root>
              <DropdownMenu.Trigger>
                {#snippet child({ props })}
                  <button
                    {...props}
                    id="filter-project"
                    type="button"
                    class="{toolbarButton} w-full"
                    aria-label="Project: {filterProject?.name ??
                      'All projects'}"
                  >
                    <span class="flex items-center gap-2 min-w-0">
                      {#if filterProject}
                        <span
                          class="size-2 shrink-0 rounded-full"
                          style="background-color: {filterProject.color}"
                          aria-hidden="true"
                        ></span>
                      {/if}
                      <span class="truncate"
                        >{filterProject?.name ?? "All projects"}</span
                      >
                    </span>
                    <ChevronDown
                      class="size-4 shrink-0 text-fg-muted"
                      aria-hidden="true"
                    />
                  </button>
                {/snippet}
              </DropdownMenu.Trigger>
              <DropdownMenu.Content align="start" class="min-w-52">
                <DropdownMenu.RadioGroup
                  value={filterProject ? String(filterProject.id) : "all"}
                  onValueChange={(value) => {
                    filters.project_id = value === "all" ? "" : value;
                    applyFilters();
                  }}
                >
                  <DropdownMenu.RadioItem
                    value="all"
                    closeOnSelect
                    class="px-2 py-1.5 rounded-[5px]"
                    >All projects</DropdownMenu.RadioItem
                  >
                  {#each projects as project (project.id)}
                    <DropdownMenu.RadioItem
                      value={String(project.id)}
                      closeOnSelect
                      class="gap-2 px-2 py-1.5 rounded-[5px]"
                    >
                      <span
                        class="size-2 shrink-0 rounded-full"
                        style="background-color: {project.color}"
                        aria-hidden="true"
                      ></span>
                      <span class="truncate">{project.name}</span>
                    </DropdownMenu.RadioItem>
                  {/each}
                </DropdownMenu.RadioGroup>
              </DropdownMenu.Content>
            </DropdownMenu.Root>
          </div>
        {/if}
        <div class="relative flex-1 min-w-40 {selecting ? '@3xl:hidden' : ''}">
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
            class="w-full h-8 pl-9 pr-3 rounded-lg bg-bg-primary border border-bg-tertiary text-base md:text-sm text-fg-primary placeholder:text-fg-dim outline-none focus:border-bright-blue transition-colors"
          />
        </div>
      </div>
    {/if}

    <div
      class="flex items-center gap-2 ml-auto {view === 'calendar'
        ? '@max-3xl:w-full'
        : ''}"
    >
      {#if view === "calendar"}
        <DropdownMenu.Root>
          <DropdownMenu.Trigger>
            {#snippet child({ props })}
              <button
                {...props}
                type="button"
                class="{toolbarButton} @max-3xl:flex-1"
              >
                {dayCount} days
                <ChevronDown class="size-4 text-fg-muted" aria-hidden="true" />
              </button>
            {/snippet}
          </DropdownMenu.Trigger>
          <DropdownMenu.Content align="end" class="min-w-44">
            <DropdownMenu.RadioGroup
              value={String(dayCount)}
              onValueChange={(value) => setDayCount(Number(value))}
            >
              <DropdownMenu.RadioItem
                value="5"
                class="px-2 py-1.5 rounded-[5px]"
                >5 days (Mon – Fri)</DropdownMenu.RadioItem
              >
              <DropdownMenu.RadioItem
                value="7"
                class="px-2 py-1.5 rounded-[5px]">7 days</DropdownMenu.RadioItem
              >
            </DropdownMenu.RadioGroup>
          </DropdownMenu.Content>
        </DropdownMenu.Root>
      {/if}
      <div
        class="flex items-center h-8 p-0.5 rounded-lg bg-bg-primary border border-bg-tertiary"
        role="radiogroup"
        aria-label="View"
      >
        {#each [{ key: "calendar", label: "Calendar", icon: CalendarDays }, { key: "list", label: "List", icon: List }] as option (option.key)}
          <button
            type="button"
            role="radio"
            aria-checked={view === option.key}
            class="inline-flex items-center gap-1.5 h-full px-2.5 rounded-[5px] text-sm font-medium transition-colors duration-150 {view ===
            option.key
              ? 'bg-bg-tertiary text-fg-primary'
              : 'text-fg-muted hover:text-fg-primary'}"
            title={option.label}
            onclick={() => switchView(option.key as "list" | "calendar")}
          >
            <option.icon class="size-4" aria-hidden="true" />
            <span class={view === option.key ? "" : "@max-md:sr-only"}
              >{option.label}</span
            >
          </button>
        {/each}
      </div>
    </div>
  </div>

  <div
    class="flex items-center gap-3 h-9 px-4 md:px-6 border-t border-bg-tertiary text-sm"
  >
    <span class="text-fg-muted shrink-0">Logged</span>
    <div
      class="flex flex-1 gap-0.5 h-1.5 rounded-full overflow-hidden bg-bg-tertiary"
      role="img"
      aria-label={loggedByProject
        .map((row) => `${row.name} ${formatHours(row.seconds)}`)
        .join(", ") || "Nothing logged"}
    >
      {#each loggedByProject as row (row.key)}
        <div
          class="h-full"
          style="flex: {row.seconds} 1 0; background-color: {row.color ??
            'var(--color-fg-dim)'}"
          title="{row.name}: {formatHours(row.seconds)}"
        ></div>
      {/each}
    </div>
    <span class="font-medium font-tabular shrink-0"
      >{formatHours(loggedTotal)}</span
    >
    <Link
      href={routes.reports.index(workspaceId)}
      class="hidden sm:inline-flex items-center gap-0.5 shrink-0 text-fg-muted hover:text-fg-primary transition-colors"
    >
      View reports <ChevronRight class="size-3.5" aria-hidden="true" />
    </Link>
  </div>
</div>

{#if view === "calendar"}
  <div class="flex-1 min-h-0">
    <WeekCalendar
      entries={calendarEntries}
      runningEntry={page.props.runningEntry}
      {projects}
      {tags}
      {weekStart}
      {dayCount}
      onDelete={openDeleteModal}
    />
  </div>
{:else}
  <div class="flex-1 overflow-auto">
    <div class="px-4 md:px-6 py-4">
      {#if !hasEntries || recentEntries.length === 0}
        <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
          {#if !hasEntries}
            <EmptyState
              icon={Clock}
              title="No time tracked yet"
              description="Type what you're working on above and press Enter to start the timer."
            />
          {:else if filters.q || filters.project_id}
            <EmptyState
              icon={SearchX}
              title="No matching entries"
              description="Nothing {periodPhrase} matches your search or project filter."
              actionLabel="Clear filters"
              onAction={clearFilters}
            />
          {:else}
            <EmptyState
              icon={CalendarDays}
              title="Nothing tracked {periodPhrase}"
              description="Use the arrows to look at another period, or start a timer above."
            />
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
                <h3 class="text-sm font-semibold">{dayLabel(group.key)}</h3>
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
                    class="group flex items-center gap-3 px-4 py-2.5 text-sm cursor-pointer transition-colors duration-150 {isSelected
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
                          class="flex items-center gap-1.5 text-sm text-fg-secondary min-w-0 shrink-0"
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
                        <span
                          class="hidden md:flex items-center gap-1 shrink-0"
                        >
                          {#each entry.tags as tag (tag.id)}
                            <span
                              class="px-1.5 py-0.5 rounded-md bg-bg-tertiary text-xs font-medium text-fg-secondary"
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
            Showing the latest {entryLimit} entries. Narrow the date range to see
            older ones.
          </p>
        {/if}
      {/if}
    </div>
  </div>
{/if}

<TimeEntryEditor
  open={showEdit}
  bind:draft={editDraft}
  entry={editingEntry}
  modal
  {projects}
  {tags}
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
