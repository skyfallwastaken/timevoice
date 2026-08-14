<script lang="ts">
  import {
    ChevronLeft,
    ChevronRight,
    Calendar as CalendarIcon,
    Clock,
  } from "lucide-svelte";
  import { router, useForm, page } from "@inertiajs/svelte";
  import IconButton from "./IconButton.svelte";
  import Modal from "./Modal.svelte";
  import Button from "./Button.svelte";
  import ChipButton from "./ChipButton.svelte";
  import TextInput from "./TextInput.svelte";
  import type { TimeEntry, Project, Tag } from "../types";
  import { toDateString } from "../lib/format";
  import { routes } from "../lib/routes";
  import {
    applySelectedProject,
    toggleSelectedTag,
  } from "../lib/time-entry-form";

  interface Props {
    entries?: TimeEntry[];
    projects?: Project[];
    tags?: Tag[];
    currentWeek: { start: string; end: string };
    onEntryClick?: (entry: TimeEntry) => void;
  }

  let {
    entries = [],
    projects = [],
    tags = [],
    currentWeek,
    onEntryClick,
  }: Props = $props();
  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  let form = useForm({
    description: "",
    project_id: null as number | null,
    tag_ids: [] as number[],
    billable: false,
    start_at: null as string | null,
    end_at: null as string | null,
  });

  const STORAGE_KEY = "calendar-show-all-hours";
  let showAllHours = $state(
    typeof localStorage !== "undefined" &&
      localStorage.getItem(STORAGE_KEY) === "true",
  );
  let startHour = $derived(showAllHours ? 0 : 6);
  let endHour = $derived(showAllHours ? 23 : 22);
  let hourHeight = 60;

  function toggleShowAllHours() {
    showAllHours = !showAllHours;
    if (typeof localStorage !== "undefined") {
      localStorage.setItem(STORAGE_KEY, String(showAllHours));
    }
  }
  let isDragging = $state(false);
  let dragStart = $state(null as { hour: number; minute: number } | null);
  let dragCurrent = $state(null as { hour: number; minute: number } | null);
  let dragDay = $state(null as Date | null);
  let showQuickEdit = $state(false);

  let entryDate = $state("");
  let startTime = $state("");
  let endTime = $state("");

  function formatTimeInput(date: Date) {
    const hh = String(date.getHours()).padStart(2, "0");
    const mm = String(date.getMinutes()).padStart(2, "0");
    return `${hh}:${mm}`;
  }

  function syncTimeFieldsFromForm() {
    if ($form.start_at) {
      const start = new Date($form.start_at);
      entryDate = toDateString(start);
      startTime = formatTimeInput(start);
    }
    if ($form.end_at) {
      endTime = formatTimeInput(new Date($form.end_at));
    }
  }

  function applyTimeFields() {
    if (!entryDate || !startTime || !endTime) return;
    const start = new Date(`${entryDate}T${startTime}:00`);
    const end = new Date(`${entryDate}T${endTime}:00`);
    // Roll the end into the next day when it lands before the start (overnight).
    if (end <= start) end.setDate(end.getDate() + 1);
    $form.start_at = start.toISOString();
    $form.end_at = end.toISOString();
  }

  function getWeekDays(weekStart: string) {
    const start = new Date(`${weekStart}T00:00:00`);
    const weekDays = [];
    for (let i = 0; i < 7; i++) {
      const day = new Date(start);
      day.setDate(start.getDate() + i);
      weekDays.push(day);
    }
    return weekDays;
  }

  function goToWeek(offsetWeeks: number) {
    const start = new Date(`${currentWeek.start}T00:00:00`);
    start.setDate(start.getDate() + offsetWeeks * 7);

    router.get(
      routes.dashboard.calendar(workspaceId),
      { week_start: toDateString(start) },
      { preserveScroll: true, preserveState: true },
    );
  }

  let days = $derived(getWeekDays(currentWeek.start));

  function formatDayHeader(date: Date) {
    return {
      dayName: date.toLocaleDateString("en-US", { weekday: "short" }),
      dayNum: date.getDate(),
    };
  }

  function formatHour(hour: number) {
    if (hour === 0) return "12 AM";
    if (hour === 12) return "12 PM";
    if (hour < 12) return `${hour} AM`;
    return `${hour - 12} PM`;
  }

  function entryBounds(entry: TimeEntry) {
    const start = new Date(entry.start_at);
    let end: Date;
    if (entry.end_at) {
      end = new Date(entry.end_at);
    } else if (entry.duration_seconds) {
      end = new Date(start.getTime() + entry.duration_seconds * 1000);
    } else {
      end = new Date(start.getTime() + 3600 * 1000);
    }
    return { start, end };
  }

  function getEntriesForDay(date: Date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);

    // Include any entry that overlaps this day, so sessions spanning midnight
    // render a segment on each day they touch.
    return entries.filter((entry) => {
      const { start, end } = entryBounds(entry);
      return start <= endOfDay && end > startOfDay;
    });
  }

  function getEntryStyle(entry: TimeEntry, day: Date) {
    const { start, end } = entryBounds(entry);

    const windowStart = new Date(day);
    windowStart.setHours(startHour, 0, 0, 0);
    const windowEnd = new Date(day);
    windowEnd.setHours(endHour + 1, 0, 0, 0);

    const visibleStart = Math.max(start.getTime(), windowStart.getTime());
    const visibleEnd = Math.min(end.getTime(), windowEnd.getTime());

    const top = ((visibleStart - windowStart.getTime()) / 3600000) * hourHeight;
    const height = ((visibleEnd - visibleStart) / 3600000) * hourHeight;

    return `top: ${top}px; height: ${Math.max(height, 20)}px;`;
  }

  function getDayTotal(date: Date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(24, 0, 0, 0);

    let totalSeconds = 0;
    getEntriesForDay(date).forEach((entry) => {
      const { start, end } = entryBounds(entry);
      // Only count the portion of the entry that falls on this day.
      const from = Math.max(start.getTime(), startOfDay.getTime());
      const to = Math.min(end.getTime(), endOfDay.getTime());
      totalSeconds += Math.max(0, (to - from) / 1000);
    });
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }

  function handleMouseDown(day: Date, event: MouseEvent) {
    const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
    const y = event.clientY - rect.top;
    const minutes = (y / hourHeight) * 60 + startHour * 60;
    const hour = Math.floor(minutes / 60);
    const minute = Math.floor((minutes % 60) / 15) * 15;

    isDragging = true;
    dragStart = { hour, minute };
    dragCurrent = { hour, minute };
    dragDay = day;
  }

  function handleMouseMove(event: MouseEvent) {
    if (!isDragging || !dragDay) return;

    const dayColumn = document.querySelector(
      `[data-day="${dragDay.toISOString()}"]`,
    );
    if (!dayColumn) return;

    const rect = dayColumn.getBoundingClientRect();
    const y = event.clientY - rect.top;
    const minutes = (y / hourHeight) * 60 + startHour * 60;
    const hour = Math.floor(minutes / 60);
    const minute = Math.floor((minutes % 60) / 15) * 15;

    dragCurrent = {
      hour: Math.max(startHour, Math.min(endHour, hour)),
      minute,
    };
  }

  function handleMouseUp() {
    if (!isDragging || !dragStart || !dragCurrent || !dragDay) return;

    let startMinutes = dragStart.hour * 60 + dragStart.minute;
    let endMinutes = dragCurrent.hour * 60 + dragCurrent.minute;

    if (startMinutes > endMinutes) {
      [startMinutes, endMinutes] = [endMinutes, startMinutes];
    }

    if (endMinutes - startMinutes < 15) {
      endMinutes = startMinutes + 15;
    }

    const startHour = Math.floor(startMinutes / 60);
    const startMinute = startMinutes % 60;
    const endHour = Math.floor(endMinutes / 60);
    const endMinute = endMinutes % 60;

    const startDate = new Date(dragDay);
    startDate.setHours(startHour, startMinute, 0, 0);

    const endDate = new Date(dragDay);
    endDate.setHours(endHour, endMinute, 0, 0);

    $form.start_at = startDate.toISOString();
    $form.end_at = endDate.toISOString();
    $form.description = "";
    $form.project_id = null;
    $form.billable = false;
    syncTimeFieldsFromForm();

    showQuickEdit = true;
    isDragging = false;
    dragStart = null;
    dragCurrent = null;
    dragDay = null;
  }

  function saveQuickEntry() {
    if (!$form.description.trim()) return;

    $form
      .transform((data) => ({
        time_entry: {
          description: data.description,
          project_id: data.project_id,
          tag_ids: data.tag_ids,
          billable: data.billable,
          start_at: data.start_at,
          end_at: data.end_at,
        },
      }))
      .post(routes.timeEntries.create(workspaceId), {
        preserveScroll: true,
        onSuccess: () => {
          showQuickEdit = false;
          $form.reset();
        },
      });
  }

  function getDragStyle() {
    if (!dragStart || !dragCurrent || !dragDay) return "";

    let startMinutes = dragStart.hour * 60 + dragStart.minute;
    let endMinutes = dragCurrent.hour * 60 + dragCurrent.minute;

    if (startMinutes > endMinutes) {
      [startMinutes, endMinutes] = [endMinutes, startMinutes];
    }

    const top = ((startMinutes - startHour * 60) / 60) * hourHeight;
    const height = ((endMinutes - startMinutes) / 60) * hourHeight;

    return `top: ${top}px; height: ${height}px;`;
  }

  function selectProject(project: { id: number; billable_default: boolean }) {
    applySelectedProject($form, project);
  }

  function toggleTag(tagId: number) {
    $form.tag_ids = toggleSelectedTag($form.tag_ids, tagId);
  }
</script>

<svelte:window onmousemove={handleMouseMove} onmouseup={handleMouseUp} />

<div class="flex flex-col h-full">
  <div
    class="flex items-center justify-between p-4 border-b border-bg-tertiary bg-bg-secondary"
  >
    <div class="flex items-center gap-3">
      <CalendarIcon class="w-6 h-6 text-bright-green" />
      <h2 class="text-2xl font-semibold">Week Calendar</h2>
    </div>
    <div class="flex items-center gap-2">
      <ChipButton
        type="button"
        aria-pressed={showAllHours}
        selected={showAllHours}
        class={showAllHours
          ? "border-bright-green text-bright-green"
          : "border-bg-tertiary text-fg-muted hover:text-fg-primary"}
        onclick={toggleShowAllHours}
      >
        <Clock class="w-4 h-4" />
        <span>{showAllHours ? "Show 6am - 10pm" : "Show 24 hours"}</span>
      </ChipButton>
      <IconButton
        type="button"
        aria-label="Previous week"
        onclick={() => goToWeek(-1)}
      >
        <ChevronLeft class="w-5 h-5" />
      </IconButton>
      <span
        class="px-4 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] font-medium min-w-50 text-center"
      >
        {currentWeek.start} - {currentWeek.end}
      </span>
      <IconButton
        type="button"
        aria-label="Next week"
        onclick={() => goToWeek(1)}
      >
        <ChevronRight class="w-5 h-5" />
      </IconButton>
    </div>
  </div>

  <div class="flex-1 overflow-auto">
    <div class="min-w-200 p-4">
      <div class="grid grid-cols-8 gap-1 mb-2">
        <div class="w-16"></div>
        {#each days as day}
          {@const header = formatDayHeader(day)}
          <div class="text-center py-2">
            <div class="text-sm text-fg-muted">{header.dayName}</div>
            <div class="text-lg font-semibold">{header.dayNum}</div>
            <div class="text-xs text-fg-dim mt-1">{getDayTotal(day)}</div>
          </div>
        {/each}
      </div>

      <div class="grid grid-cols-8 gap-1 relative">
        <div class="w-16 flex flex-col">
          {#each Array.from({ length: endHour - startHour + 1 }, (_, i) => startHour + i) as hour}
            <div
              class="text-xs text-fg-muted text-right pr-2"
              style="height: {hourHeight}px; line-height: {hourHeight}px;"
            >
              {formatHour(hour)}
            </div>
          {/each}
        </div>

        {#each days as day}
          <div
            class="relative border-l border-bg-tertiary bg-bg-primary/50"
            data-day={day.toISOString()}
            style="height: {(endHour - startHour + 1) * hourHeight}px;"
            onmousedown={(e) => handleMouseDown(day, e)}
            role="button"
            tabindex="0"
            aria-label="Day {day.toDateString()}"
          >
            {#each Array.from({ length: endHour - startHour }, (_, i) => i) as _}
              <div
                class="border-b border-bg-tertiary/30"
                style="height: {hourHeight}px;"
              ></div>
            {/each}

            {#each getEntriesForDay(day) as entry}
              <button
                type="button"
                class="absolute left-1 right-1 rounded-md px-2 py-1 text-xs overflow-hidden cursor-pointer hover:brightness-110 transition-all duration-200 text-left"
                style="{getEntryStyle(entry, day)} background-color: {entry
                  .project?.color || '#b16286'}40; border-left: 3px solid {entry
                  .project?.color || '#b16286'};"
                title="{entry.description ||
                  'No description'} ({entry.formattedDuration})"
                onmousedown={(e) => e.stopPropagation()}
                onclick={(e) => {
                  e.stopPropagation();
                  onEntryClick?.(entry);
                }}
              >
                <div class="font-medium truncate text-fg-primary">
                  {entry.description || "No description"}
                </div>
                <div class="text-fg-secondary truncate">
                  {entry.formattedDuration}
                </div>
              </button>
            {/each}

            {#if isDragging && dragDay?.toDateString() === day.toDateString()}
              <div
                class="absolute left-1 right-1 rounded-md bg-bright-blue/30 border-2 border-bright-blue border-dashed pointer-events-none"
                style={getDragStyle()}
              ></div>
            {/if}
          </div>
        {/each}
      </div>
    </div>
  </div>
</div>

<Modal
  open={showQuickEdit}
  title="New Time Entry"
  onclose={() => (showQuickEdit = false)}
  maxWidth="max-w-md"
>
  <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
    <div>
      <label for="entry-date" class="block text-sm font-medium mb-2">Date</label
      >
      <input
        id="entry-date"
        type="date"
        bind:value={entryDate}
        onchange={applyTimeFields}
        class="w-full px-3 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-primary focus-visible:outline-none focus-visible:border-bright-blue"
      />
    </div>
    <div>
      <label for="entry-start" class="block text-sm font-medium mb-2"
        >Start</label
      >
      <input
        id="entry-start"
        type="time"
        bind:value={startTime}
        onchange={applyTimeFields}
        class="w-full px-3 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-primary focus-visible:outline-none focus-visible:border-bright-blue"
      />
    </div>
    <div>
      <label for="entry-end" class="block text-sm font-medium mb-2">End</label>
      <input
        id="entry-end"
        type="time"
        bind:value={endTime}
        onchange={applyTimeFields}
        class="w-full px-3 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-primary focus-visible:outline-none focus-visible:border-bright-blue"
      />
    </div>
  </div>

  <div>
    <label for="entry-description" class="block text-sm font-medium mb-2"
      >Description</label
    >
    <TextInput
      id="entry-description"
      type="text"
      placeholder="What did you work on?"
      bind:value={$form.description}
      tone="blue"
    />
  </div>

  <div>
    <span class="block text-sm font-medium mb-2">Project</span>
    <div class="grid grid-cols-4 gap-2 max-h-32 overflow-y-auto">
      {#each projects as project}
        <button
          type="button"
          onclick={() => selectProject(project)}
          class="p-2 rounded-lg border text-xs text-left transition-colors duration-150 {$form.project_id ===
          project.id
            ? 'border-bright-blue bg-bright-blue/20'
            : 'border-bg-tertiary hover:border-fg-muted'}"
        >
          <span
            class="block w-3 h-3 rounded-full mb-1"
            style="background-color: {project.color}"
          ></span>
          <span class="truncate block">{project.name}</span>
        </button>
      {/each}
    </div>
  </div>

  {#if tags.length > 0}
    <div>
      <span class="block text-sm font-medium mb-2">Tags</span>
      <div class="flex flex-wrap gap-2">
        {#each tags as tag}
          <ChipButton
            type="button"
            selected={$form.tag_ids.includes(tag.id)}
            class={$form.tag_ids.includes(tag.id)
              ? "border-bright-green text-bright-green"
              : "text-fg-muted hover:text-fg-primary"}
            onclick={() => toggleTag(tag.id)}
          >
            {tag.name}
          </ChipButton>
        {/each}
      </div>
    </div>
  {/if}

  <div class="flex items-center justify-between">
    <ChipButton
      type="button"
      selected={$form.billable}
      class={$form.billable
        ? "border-bright-green text-bright-green"
        : "border-bg-tertiary text-fg-muted hover:text-fg-primary"}
      onclick={() => ($form.billable = !$form.billable)}
    >
      <span>Billable</span>
    </ChipButton>

    <div class="flex gap-2">
      <Button
        type="button"
        variant="secondary"
        onclick={() => (showQuickEdit = false)}
      >
        Cancel
      </Button>
      <Button
        type="button"
        tone="blue"
        onclick={saveQuickEntry}
        disabled={!$form.description.trim()}
      >
        Save Entry
      </Button>
    </div>
  </div>
</Modal>
