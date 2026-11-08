<script lang="ts">
  import { DollarSign, Timer } from "@lucide/svelte";
  import TimeEntryEditor from "./TimeEntryEditor.svelte";
  import type { TimeEntry, Project, Tag } from "../types";
  import { formatHours, toDateString } from "../lib/format";
  import { draftFromEntry, type TimeEntryDraft } from "../lib/time-entry-form";

  type RunningEntry = {
    id: number;
    description: string | null;
    start_at: string;
    billable: boolean;
    project: TimeEntry["project"];
  };

  interface Props {
    entries?: TimeEntry[];
    runningEntry?: RunningEntry | null;
    projects?: Project[];
    tags?: Tag[];
    weekStart: string;
    dayCount?: number;
    onDelete?: (entry: TimeEntry) => void;
  }

  let {
    entries = [],
    runningEntry = null,
    projects = [],
    tags = [],
    weekStart,
    dayCount = 7,
    onDelete,
  }: Props = $props();

  const HOUR = 52;
  const DAY_MINUTES = 24 * 60;
  const pxPerMinute = HOUR / 60;

  let now = $state(new Date());
  $effect(() => {
    const interval = setInterval(() => (now = new Date()), 30_000);
    return () => clearInterval(interval);
  });

  let days = $derived.by(() => {
    const start = new Date(`${weekStart}T00:00:00`);
    return Array.from({ length: dayCount }, (_, i) => {
      const day = new Date(start);
      day.setDate(start.getDate() + i);
      return day;
    });
  });
  let todayKey = $derived(toDateString(now));
  let columns = $derived(`4rem repeat(${dayCount}, minmax(0, 1fr))`);

  type Block = {
    entry: TimeEntry;
    running: boolean;
    start: number;
    end: number;
    lane: number;
    lanes: number;
  };

  // The running timer is drawn as a block that grows until now. The entry
  // being edited is drawn as the editable selection instead of a block.
  let allEntries = $derived.by(() => {
    const list = entries
      .filter((entry) => entry.id !== editingId)
      .map((entry) => ({ entry, running: false }));
    if (runningEntry) {
      list.push({
        entry: {
          ...runningEntry,
          end_at: now.toISOString(),
          formattedDuration: "",
          tags: [],
        },
        running: true,
      });
    }
    return list;
  });

  const minutesIntoDay = (date: Date) =>
    date.getHours() * 60 + date.getMinutes();

  // Overlapping entries share the column width, like a calendar app.
  function layoutDay(day: Date): Block[] {
    const key = toDateString(day);
    const items = allEntries
      .filter(({ entry }) => toDateString(new Date(entry.start_at)) === key)
      .map(({ entry, running }) => {
        const start = new Date(entry.start_at);
        const end = entry.end_at
          ? new Date(entry.end_at)
          : new Date(start.getTime() + (entry.duration_seconds ?? 0) * 1000);
        const from = minutesIntoDay(start);
        const minutes = (end.getTime() - start.getTime()) / 60_000;
        return {
          entry,
          running,
          start: from,
          end: Math.min(DAY_MINUTES, from + Math.max(minutes, 25)),
          lane: 0,
          lanes: 1,
        };
      })
      .sort((a, b) => a.start - b.start || b.end - a.end);

    let cluster: Block[] = [];
    let laneEnds: number[] = [];
    let clusterEnd = -1;
    const flush = () => {
      for (const block of cluster) block.lanes = laneEnds.length;
      cluster = [];
      laneEnds = [];
    };
    for (const block of items) {
      if (block.start >= clusterEnd) flush();
      let lane = laneEnds.findIndex((end) => end <= block.start);
      if (lane === -1) lane = laneEnds.push(block.end) - 1;
      else laneEnds[lane] = block.end;
      block.lane = lane;
      cluster.push(block);
      clusterEnd = Math.max(clusterEnd, block.end);
    }
    flush();
    return items;
  }

  let blocksByDay = $derived(days.map(layoutDay));

  // Completed time only, so the totals match the Logged bar.
  function dayTotal(day: Date) {
    const key = toDateString(day);
    return entries.reduce(
      (sum, entry) =>
        toDateString(new Date(entry.start_at)) === key
          ? sum + (entry.duration_seconds ?? 0)
          : sum,
      0,
    );
  }

  // Pick black or white text, whichever contrasts more with the fill.
  function textOn(hex: string) {
    const channel = (offset: number) => {
      const c = parseInt(hex.slice(offset, offset + 2), 16) / 255;
      return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    };
    const luminance =
      0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
    return (luminance + 0.05) / 0.05 > 1.05 / (luminance + 0.05)
      ? "#000000"
      : "#ffffff";
  }

  function hourLabel(hour: number) {
    const suffix = hour < 12 ? "AM" : "PM";
    return `${hour % 12 || 12} ${suffix}`;
  }

  // When the days don't all fit (phones), widen the columns so a whole
  // number of them fill the view; scrolling then always ends on a column edge.
  const HOURS_WIDTH = 64;
  const MIN_COLUMN = 104;
  let viewWidth = $state(0);
  let columnWidth = $derived.by(() => {
    const room = viewWidth - HOURS_WIDTH;
    const fits = Math.max(1, Math.floor(room / MIN_COLUMN));
    return viewWidth && fits < dayCount ? room / fits : null;
  });

  // Start scrolled to the first tracked hour of the week, or 8 AM, with
  // today's column in view at the left edge.
  let scroller: HTMLDivElement | null = $state(null);
  let scrolledWeek = "";
  $effect(() => {
    if (!scroller || !viewWidth || scrolledWeek === weekStart) return;
    scrolledWeek = weekStart;
    const firstHour = Math.min(
      8,
      ...entries.map((e) => new Date(e.start_at).getHours()),
    );
    scroller.scrollTop = Math.max(0, (firstHour - 1) * HOUR - 12);
    const today = scroller.querySelector<HTMLElement>("[data-today]");
    if (today && columnWidth) {
      scroller.scrollLeft = Number(today.dataset.dayIndex) * columnWidth;
    }
  });

  // Drag on an empty part of a day to select a time for a new entry, or click
  // an entry to edit it. The selection stays editable like Google Calendar's:
  // drag it to move it, drag its bottom edge to resize it, drag elsewhere to
  // replace it, or type the times in the popover. Minutes can run past 24:00
  // for overnight entries.
  let selection = $state<TimeEntryDraft | null>(null);
  let editingId = $state<number | null>(null);
  let editingEntry = $derived(
    entries.find((entry) => entry.id === editingId) ?? null,
  );
  let gesture: {
    mode: "create" | "move" | "resize";
    grab: number;
    from: number;
    to: number;
    column: HTMLElement;
  } | null = null;
  let showQuickEdit = $state(false);
  let placeholder: HTMLElement | null = $state(null);

  let selectedProject = $derived(
    projects.find((p) => p.id === selection?.project_id),
  );

  function minuteAt(event: PointerEvent, column: HTMLElement) {
    const y = event.clientY - column.getBoundingClientRect().top;
    const minute = Math.round(y / pxPerMinute / 15) * 15;
    return Math.max(0, Math.min(DAY_MINUTES, minute));
  }

  function dayAt(x: number) {
    const columns = scroller?.querySelectorAll<HTMLElement>("[data-day-index]");
    for (const column of columns ?? []) {
      const { left, right } = column.getBoundingClientRect();
      if (x >= left && x < right) return days[Number(column.dataset.dayIndex)];
    }
    return null;
  }

  function startDrag(event: PointerEvent, day: Date) {
    if (event.button !== 0 || event.pointerType === "touch") return;
    const column = event.currentTarget as HTMLElement;
    const minute = Math.min(
      DAY_MINUTES - 15,
      Math.floor(minuteAt(event, column) / 15) * 15,
    );
    // Dragging away from an entry being edited starts a new one instead.
    if (editingId !== null) {
      editingId = null;
      showQuickEdit = false;
    }
    // Re-dragging while the popover is open keeps what was already filled in.
    const fields = (showQuickEdit && selection) || {
      description: "",
      project_id: null,
      tag_ids: [],
      billable: false,
    };
    selection = { ...fields, day, from: minute, to: minute };
    gesture = {
      mode: "create",
      grab: minute,
      from: minute,
      to: minute,
      column,
    };
  }

  function adjustSelection(event: PointerEvent, mode: "move" | "resize") {
    if (event.button !== 0 || !selection) return;
    event.stopPropagation();
    const column = (event.currentTarget as HTMLElement).closest<HTMLElement>(
      "[data-day-index]",
    )!;
    gesture = {
      mode,
      grab: minuteAt(event, column),
      from: selection.from,
      to: selection.to,
      column,
    };
  }

  function moveDrag(event: PointerEvent) {
    if (!gesture || !selection) return;
    const minute = minuteAt(event, gesture.column);
    if (gesture.mode === "create") {
      selection.from = Math.min(gesture.grab, minute);
      selection.to = Math.max(gesture.grab, minute);
    } else if (gesture.mode === "resize") {
      selection.to = Math.max(gesture.from + 15, minute);
    } else {
      const length = gesture.to - gesture.from;
      const from = Math.max(
        0,
        Math.min(DAY_MINUTES - length, gesture.from + minute - gesture.grab),
      );
      selection.from = from;
      selection.to = from + length;
      const day = dayAt(event.clientX);
      if (day && day.getTime() !== selection.day.getTime()) selection.day = day;
    }
  }

  function endDrag() {
    if (!gesture || !selection) return;
    const { mode } = gesture;
    gesture = null;
    if (mode !== "create") return;
    if (selection.to - selection.from < 15)
      selection.to = Math.min(DAY_MINUTES, selection.from + 30);
    showQuickEdit = true;
  }

  function cancelDrag() {
    gesture = null;
    if (!showQuickEdit) selection = null;
  }

  function editEntry(entry: TimeEntry) {
    editingId = entry.id;
    selection = draftFromEntry(entry);
    showQuickEdit = true;
  }

  // The dashed placeholder stays while the entry's details are filled in,
  // and until the popover has faded out so its contents don't change mid-fade.
  // A drag or edit started during the fade owns the new selection.
  function closeQuickEdit() {
    showQuickEdit = false;
  }

  function clearClosedSelection() {
    if (gesture || showQuickEdit) return;
    selection = null;
    editingId = null;
  }

  const clock = (minute: number) => {
    const date = new Date(0, 0, 1, 0, minute);
    return date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });
  };

  // Clicks on empty calendar space edit the selection instead of closing.
  function keepOpenForCalendar(event: PointerEvent) {
    const target = event.target as Element | null;
    if (target?.closest("[data-day-index]") && !target.closest("button"))
      event.preventDefault();
  }
</script>

<svelte:window
  onpointermove={moveDrag}
  onpointerup={endDrag}
  onpointercancel={cancelDrag}
/>

<div
  bind:this={scroller}
  bind:clientWidth={viewWidth}
  class="h-full overflow-auto snap-x snap-mandatory scroll-pl-16"
>
  <div
    style="min-width: {columnWidth
      ? `${HOURS_WIDTH + dayCount * columnWidth}px`
      : `calc(4rem + ${dayCount} * 6.5rem)`}"
  >
    <div
      class="sticky top-0 z-30 grid bg-bg-primary border-b border-bg-tertiary"
      style="grid-template-columns: {columns}"
    >
      <div class="sticky left-0 z-10 bg-bg-primary"></div>
      {#each days as day, i (day.getTime())}
        {@const isToday = toDateString(day) === todayKey}
        {@const total = dayTotal(day)}
        <div
          class="flex items-center gap-1.5 h-14 px-2 border-l border-bg-tertiary min-w-0"
        >
          <span
            class="grid place-items-center size-9 shrink-0 rounded-full text-xl font-medium font-tabular {isToday
              ? 'bg-bright-purple text-bg-primary'
              : 'text-fg-primary'}">{day.getDate()}</span
          >
          <div class="min-w-0 leading-tight">
            <div
              class="text-sm font-medium {isToday
                ? 'text-bright-purple'
                : 'text-fg-secondary'}"
            >
              {day.toLocaleDateString("en-US", { weekday: "short" })}
            </div>
            <div
              class="text-xs font-tabular whitespace-nowrap {total
                ? 'text-bright-purple'
                : 'text-fg-dim'}"
            >
              {total ? formatHours(total) : "–"}
            </div>
          </div>
        </div>
      {/each}
    </div>

    <div class="grid" style="grid-template-columns: {columns}">
      <div
        class="sticky left-0 z-20 bg-bg-primary"
        style="height: {24 * HOUR}px"
        aria-hidden="true"
      >
        {#each Array.from({ length: 23 }, (_, i) => i + 1) as hour}
          <span
            class="absolute right-2 -translate-y-1/2 text-xs text-fg-muted font-tabular whitespace-nowrap"
            style="top: {hour * HOUR}px">{hourLabel(hour)}</span
          >
        {/each}
      </div>

      {#each days as day, i (day.getTime())}
        {@const isToday = toDateString(day) === todayKey}
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          class="relative snap-start border-l border-bg-tertiary select-none {isToday
            ? 'bg-bright-purple/[0.03]'
            : ''}"
          style="height: {24 *
            HOUR}px; background-image: repeating-linear-gradient(to bottom, transparent 0 {HOUR -
            1}px, var(--color-bg-tertiary) {HOUR - 1}px {HOUR}px);"
          data-today={isToday || undefined}
          data-day-index={i}
          onpointerdown={(e) => startDrag(e, day)}
        >
          {#each blocksByDay[i] as block (block.running ? "running" : block.entry.id)}
            {@const { entry } = block}
            {@const color = entry.project?.color}
            {@const height = (block.end - block.start) * pxPerMinute - 2}
            {@const seconds = block.running
              ? (now.getTime() - new Date(entry.start_at).getTime()) / 1000
              : (entry.duration_seconds ?? 0)}
            <button
              type="button"
              class="absolute flex flex-col gap-px overflow-hidden rounded-md px-2 text-left text-xs cursor-pointer transition-[filter] duration-150 hover:brightness-110 {height <
              40
                ? 'py-px'
                : 'py-1.5'} {color
                ? ''
                : 'bg-bg-secondary ring-1 ring-inset ring-bg-quaternary text-fg-primary'} {block.running
                ? 'ring-2 ring-inset ring-white/50'
                : ''}"
              style="top: {block.start * pxPerMinute +
                1}px; height: {height}px; left: calc({(block.lane /
                block.lanes) *
                100}% + 3px); width: calc({100 / block.lanes}% - 6px); {color
                ? `background-color: ${color}; color: ${textOn(color)};`
                : ''}"
              title="{entry.project
                ? `${entry.project.name}: `
                : ''}{entry.description || 'No description'} ({formatHours(
                seconds,
              )})"
              onpointerdown={(e) => e.stopPropagation()}
              onclick={() => !block.running && editEntry(entry)}
            >
              {#if height < 18}
                <!-- Too short for text; the title carries the details. -->
              {:else if height < 40}
                <span class="truncate font-semibold">
                  {entry.project?.name ?? entry.description ?? "No description"}
                  {#if entry.project && entry.description}
                    <span class="font-normal">· {entry.description}</span>
                  {/if}
                </span>
              {:else}
                <span class="flex items-baseline justify-between gap-2">
                  <span class="truncate font-semibold"
                    >{entry.project?.name ??
                      entry.description ??
                      "No description"}</span
                  >
                  {#if height < 64}
                    <span class="shrink-0 font-medium font-tabular"
                      >{formatHours(seconds)}</span
                    >
                  {/if}
                </span>
                {#if entry.project && entry.description}
                  <span class={height >= 90 ? "line-clamp-2" : "truncate"}
                    >{entry.description}</span
                  >
                {/if}
                {#if height >= 64}
                  <span
                    class="mt-auto flex items-center justify-between gap-2 font-medium font-tabular"
                  >
                    <span class="flex items-center gap-1">
                      {#if block.running}
                        <span
                          class="size-1.5 rounded-full bg-current animate-pulse"
                        ></span>
                      {:else}
                        <Timer class="size-3" aria-hidden="true" />
                      {/if}
                      {formatHours(seconds)}
                    </span>
                    {#if entry.billable}
                      <DollarSign class="size-3" aria-label="Billable" />
                    {/if}
                  </span>
                {/if}
              {/if}
            </button>
          {/each}

          {#if selection && selection.day.getTime() === day.getTime()}
            {@const color = selectedProject?.color}
            {@const shownTo = Math.max(selection.to, selection.from + 15)}
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <div
              bind:this={placeholder}
              class="absolute inset-x-[3px] z-10 flex flex-col overflow-hidden rounded-md border-2 border-dashed px-1.5 py-0.5 text-xs font-medium font-tabular {color
                ? 'text-fg-primary'
                : 'border-bright-purple bg-bright-purple/15 text-bright-purple'} {showQuickEdit
                ? 'cursor-grab active:cursor-grabbing shadow-lg'
                : 'pointer-events-none'}"
              style="top: {selection.from * pxPerMinute}px; height: {(Math.min(
                DAY_MINUTES,
                shownTo,
              ) -
                selection.from) *
                pxPerMinute}px; {color
                ? `border-color: ${color}; background-color: ${color}33;`
                : ''}"
              onpointerdown={(e) => adjustSelection(e, "move")}
            >
              {#if selection.description.trim()}
                <span class="truncate font-semibold"
                  >{selection.description}</span
                >
              {/if}
              <span class="truncate"
                >{clock(selection.from)} – {clock(shownTo)}</span
              >
              {#if showQuickEdit}
                <span
                  class="absolute inset-x-0 bottom-0 h-2 cursor-ns-resize"
                  aria-hidden="true"
                  onpointerdown={(e) => adjustSelection(e, "resize")}
                ></span>
              {/if}
            </div>
          {/if}

          {#if isToday}
            <div
              class="absolute inset-x-0 z-10 h-0.5 bg-bright-red pointer-events-none"
              style="top: {minutesIntoDay(now) * pxPerMinute}px"
              aria-hidden="true"
            >
              <span
                class="absolute -left-1 -top-[3px] size-2 rounded-full bg-bright-red"
              ></span>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  </div>
</div>

<TimeEntryEditor
  open={showQuickEdit}
  bind:draft={selection}
  entry={editingEntry}
  anchor={placeholder}
  {projects}
  {tags}
  minDay={days[0]}
  maxDay={days[days.length - 1]}
  onClose={closeQuickEdit}
  onClosed={clearClosedSelection}
  {onDelete}
  onInteractOutside={keepOpenForCalendar}
/>
