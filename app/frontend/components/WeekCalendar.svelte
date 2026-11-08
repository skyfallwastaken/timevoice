<script lang="ts">
  import { Clock, DollarSign, Folder, Hash, Timer, X } from "lucide-svelte";
  import { useForm, page } from "@inertiajs/svelte";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Command from "$lib/components/ui/command/index.js";
  import Button from "./Button.svelte";
  import DatePicker from "./DatePicker.svelte";
  import type { TimeEntry, Project, Tag } from "../types";
  import { formatHours, toDateString } from "../lib/format";
  import { routes } from "../lib/routes";
  import { toggleSelectedTag } from "../lib/time-entry-form";

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
    onEntryClick?: (entry: TimeEntry) => void;
  }

  let {
    entries = [],
    runningEntry = null,
    projects = [],
    tags = [],
    weekStart,
    dayCount = 7,
    onEntryClick,
  }: Props = $props();
  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

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

  // The running timer is drawn as a block that grows until now.
  let allEntries = $derived.by(() => {
    const list = entries.map((entry) => ({ entry, running: false }));
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
  function dayTotal(blocks: Block[]) {
    return blocks.reduce(
      (sum, { entry, running }) =>
        running ? sum : sum + (entry.duration_seconds ?? 0),
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

  // Start scrolled to the first tracked hour of the week, or 8 AM, with
  // today's column in view.
  let scroller: HTMLDivElement | null = $state(null);
  let scrolledWeek = "";
  $effect(() => {
    if (!scroller || scrolledWeek === weekStart) return;
    scrolledWeek = weekStart;
    const firstHour = Math.min(
      8,
      ...entries.map((e) => new Date(e.start_at).getHours()),
    );
    scroller.scrollTop = Math.max(0, (firstHour - 1) * HOUR - 12);
    const today = scroller.querySelector<HTMLElement>("[data-today]");
    if (today && today.offsetLeft + today.offsetWidth > scroller.clientWidth) {
      scroller.scrollLeft = today.offsetLeft - 64;
    }
  });

  // Drag on an empty part of a day to select a time for a new entry. The
  // selection stays editable like Google Calendar's: drag it to move it, drag
  // its bottom edge to resize it, drag elsewhere to replace it, or type the
  // times in the popover. Minutes can run past 24:00 for overnight entries.
  type Selection = { day: Date; from: number; to: number };
  let selection = $state<Selection | null>(null);
  let gesture: {
    mode: "create" | "move" | "resize";
    grab: number;
    from: number;
    to: number;
    column: HTMLElement;
  } | null = null;
  let showQuickEdit = $state(false);
  let placeholder: HTMLElement | null = $state(null);
  let descriptionInput: HTMLInputElement | null = $state(null);
  let showProjectPicker = $state(false);
  let showTagPicker = $state(false);

  let form = useForm({
    description: "",
    project_id: null as number | null,
    tag_ids: [] as number[],
    billable: false,
  });

  let selectedProject = $derived(
    projects.find((p) => p.id === $form.project_id),
  );
  let selectedTags = $derived(tags.filter((t) => $form.tag_ids.includes(t.id)));

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
    selection = { day, from: minute, to: minute };
    gesture = {
      mode: "create",
      grab: minute,
      from: minute,
      to: minute,
      column,
    };
    showProjectPicker = showTagPicker = false;
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
    showProjectPicker = showTagPicker = false;
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
    // Re-dragging while the popover is open keeps what was already filled in.
    if (!showQuickEdit) {
      $form.reset();
      showQuickEdit = true;
    }
  }

  function cancelDrag() {
    gesture = null;
    if (!showQuickEdit) selection = null;
  }

  const pad = (n: number) => String(n).padStart(2, "0");
  const timeOfDay = (minute: number) =>
    `${pad(Math.floor(minute / 60) % 24)}:${pad(minute % 60)}`;
  const parseTime = (value: string) => {
    const [hours, minutes] = value.split(":").map(Number);
    return hours * 60 + minutes;
  };

  // A new start time keeps the entry's length, like Google Calendar.
  function setStart(value: string) {
    if (!value || !selection) return;
    const length = selection.to - selection.from;
    selection.from = parseTime(value);
    selection.to = selection.from + length;
  }

  // An end time at or before the start means the entry ran past midnight.
  function setEnd(value: string) {
    if (!value || !selection) return;
    const to = parseTime(value);
    selection.to = to <= selection.from ? to + DAY_MINUTES : to;
  }

  function saveQuickEntry() {
    if (!$form.description.trim() || !selection) return;
    const { day, from, to } = selection;
    const at = (minute: number) => {
      const date = new Date(day);
      date.setHours(0, minute, 0, 0);
      return date.toISOString();
    };
    $form
      .transform((data) => ({
        time_entry: { ...data, start_at: at(from), end_at: at(to) },
      }))
      .post(routes.timeEntries.create(workspaceId), {
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => {
          closeQuickEdit();
          $form.reset();
        },
      });
  }

  // The dashed placeholder stays while the new entry's details are filled in.
  function closeQuickEdit() {
    showQuickEdit = false;
    selection = null;
  }

  const clock = (minute: number) => {
    const date = new Date(0, 0, 1, 0, minute);
    return date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });
  };

  function selectProject(project: Project | null) {
    $form.project_id = project?.id ?? null;
    if (project?.billable_default) $form.billable = true;
    showProjectPicker = false;
  }

  // Clicks on empty calendar space edit the selection instead of closing.
  function keepOpenForCalendar(event: PointerEvent) {
    const target = event.target as Element | null;
    if (target?.closest("[data-day-index]") && !target.closest("button"))
      event.preventDefault();
  }

  const row =
    "flex items-center gap-3 w-full min-h-9 -mx-2 px-2 rounded-lg text-left transition-colors duration-150";
  const rowButton = `${row} hover:bg-bg-tertiary data-[state=open]:bg-bg-tertiary`;
  const timeField =
    "bg-transparent text-fg-primary font-tabular h-8 px-1.5 rounded-lg hover:bg-bg-tertiary focus:bg-bg-tertiary outline-none transition-colors duration-150 [&::-webkit-calendar-picker-indicator]:hidden";
</script>

<svelte:window
  onpointermove={moveDrag}
  onpointerup={endDrag}
  onpointercancel={cancelDrag}
/>

<div bind:this={scroller} class="h-full overflow-auto">
  <div style="min-width: calc(4rem + {dayCount} * 6.5rem)">
    <div
      class="sticky top-0 z-30 grid bg-bg-primary border-b border-bg-tertiary"
      style="grid-template-columns: {columns}"
    >
      <div class="sticky left-0 z-10 bg-bg-primary"></div>
      {#each days as day, i (day.getTime())}
        {@const isToday = toDateString(day) === todayKey}
        {@const total = dayTotal(blocksByDay[i])}
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
          class="relative border-l border-bg-tertiary select-none {isToday
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
              onclick={() => !block.running && onEntryClick?.(entry)}
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
              {#if $form.description.trim()}
                <span class="truncate font-semibold">{$form.description}</span>
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

<Popover.Root
  open={showQuickEdit}
  onOpenChange={(open) => !open && closeQuickEdit()}
>
  <Popover.Content
    customAnchor={placeholder}
    side="right"
    align="start"
    sideOffset={10}
    collisionPadding={12}
    updatePositionStrategy="always"
    class="w-[26rem] max-w-[calc(100vw-1.5rem)] gap-0 p-0 shadow-2xl"
    aria-label="New time entry"
    onOpenAutoFocus={(e) => {
      e.preventDefault();
      descriptionInput?.focus();
    }}
    onCloseAutoFocus={(e) => e.preventDefault()}
    onInteractOutside={keepOpenForCalendar}
  >
    <div class="flex items-center justify-between pl-4 pr-2 pt-2">
      <span class="text-xs font-medium text-fg-muted">New time entry</span>
      <button
        type="button"
        class="inline-flex items-center justify-center size-8 rounded-lg text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors duration-150"
        aria-label="Close"
        onclick={closeQuickEdit}
      >
        <X class="size-4" aria-hidden="true" />
      </button>
    </div>

    <div class="px-4 pb-4 space-y-3">
      <input
        bind:this={descriptionInput}
        bind:value={$form.description}
        id="quick-entry-description"
        type="text"
        aria-label="Description"
        placeholder="What did you work on?"
        autocomplete="off"
        class="w-full h-11 bg-transparent border-b-2 border-bg-tertiary focus:border-bright-purple text-xl font-semibold text-fg-primary placeholder:font-medium placeholder:text-fg-dim outline-none transition-colors duration-150"
        onkeydown={(e) => e.key === "Enter" && saveQuickEntry()}
      />

      {#if selection}
        {@const sel = selection}
        <div>
          <div class="{row} items-start pb-1">
            <Clock
              class="size-4 shrink-0 mt-2 text-fg-muted"
              aria-hidden="true"
            />
            <div class="min-w-0 -ml-1.5">
              <div class="flex flex-wrap items-center gap-x-1">
                <DatePicker
                  id="quick-entry-date"
                  bind:value={() => sel.day, (date) => date && (sel.day = date)}
                  min={days[0]}
                  max={days[days.length - 1]}
                  format={(date) =>
                    date.toLocaleDateString("en-US", {
                      weekday: "long",
                      month: "short",
                      day: "numeric",
                    })}
                  class="w-auto h-8 gap-1.5 px-1.5 rounded-lg border-transparent bg-transparent hover:bg-bg-tertiary hover:border-transparent data-[state=open]:border-transparent data-[state=open]:bg-bg-tertiary [&>svg]:hidden"
                />
                <div class="flex items-center gap-0.5">
                  <input
                    type="time"
                    aria-label="Start time"
                    value={timeOfDay(sel.from)}
                    oninput={(e) => setStart(e.currentTarget.value)}
                    class={timeField}
                  />
                  <span class="text-fg-dim" aria-hidden="true">–</span>
                  <input
                    type="time"
                    aria-label="End time"
                    value={timeOfDay(sel.to)}
                    oninput={(e) => setEnd(e.currentTarget.value)}
                    class={timeField}
                  />
                </div>
              </div>
              <p class="px-1.5 text-xs text-fg-muted font-tabular">
                <span class="font-medium text-bright-purple"
                  >{formatHours((sel.to - sel.from) * 60)}</span
                >{sel.to > DAY_MINUTES ? " · Ends the next day" : ""}
              </p>
            </div>
          </div>

          {#if projects.length > 0}
            <Popover.Root bind:open={showProjectPicker}>
              <Popover.Trigger class={rowButton}>
                {#if selectedProject}
                  <span
                    class="grid place-items-center size-4 shrink-0"
                    aria-hidden="true"
                  >
                    <span
                      class="size-2.5 rounded-full"
                      style="background-color: {selectedProject.color}"
                    ></span>
                  </span>
                  <span class="truncate text-fg-primary"
                    >{selectedProject.name}</span
                  >
                  {#if selectedProject.client}
                    <span class="truncate text-fg-muted"
                      >· {selectedProject.client.name}</span
                    >
                  {/if}
                {:else}
                  <Folder
                    class="size-4 shrink-0 text-fg-muted"
                    aria-hidden="true"
                  />
                  <span class="text-fg-muted">Add project</span>
                {/if}
              </Popover.Trigger>
              <Popover.Content align="start" class="w-64 p-0">
                <Command.Root>
                  <Command.Input placeholder="Search projects..." />
                  <Command.List>
                    <Command.Empty>No matching projects.</Command.Empty>
                    {#if selectedProject}
                      <Command.Item
                        value="No project"
                        onSelect={() => selectProject(null)}
                        class="gap-3 px-3 py-2 rounded-[5px] text-fg-muted"
                      >
                        <X class="w-3 h-3" aria-hidden="true" />
                        No project
                      </Command.Item>
                    {/if}
                    {#each projects as project (project.id)}
                      <Command.Item
                        value={`${project.name} ${project.client?.name ?? ""}`}
                        data-checked={$form.project_id === project.id}
                        onSelect={() => selectProject(project)}
                        class="gap-3 px-3 py-2 rounded-[5px]"
                      >
                        <span
                          class="w-3 h-3 rounded-full shrink-0"
                          style="background-color: {project.color}"
                          aria-hidden="true"
                        ></span>
                        <div class="flex-1 min-w-0">
                          <p class="text-fg-primary truncate">
                            {project.name}
                          </p>
                          {#if project.client}
                            <p class="text-xs text-fg-muted truncate">
                              {project.client.name}
                            </p>
                          {/if}
                        </div>
                      </Command.Item>
                    {/each}
                  </Command.List>
                </Command.Root>
              </Popover.Content>
            </Popover.Root>
          {/if}

          {#if tags.length > 0}
            <Popover.Root bind:open={showTagPicker}>
              <Popover.Trigger class={rowButton}>
                <Hash
                  class="size-4 shrink-0 text-fg-muted"
                  aria-hidden="true"
                />
                {#if selectedTags.length > 0}
                  <span class="flex flex-wrap gap-1 py-1.5">
                    {#each selectedTags as tag (tag.id)}
                      <span
                        class="px-1.5 py-0.5 rounded-md bg-bg-tertiary text-xs font-medium text-fg-primary"
                        >{tag.name}</span
                      >
                    {/each}
                  </span>
                {:else}
                  <span class="text-fg-muted">Add tags</span>
                {/if}
              </Popover.Trigger>
              <Popover.Content align="start" class="w-56 p-0">
                <Command.Root>
                  <Command.Input placeholder="Search tags..." />
                  <Command.List>
                    <Command.Empty>No matching tags.</Command.Empty>
                    {#each tags as tag (tag.id)}
                      <Command.Item
                        value={tag.name}
                        data-checked={$form.tag_ids.includes(tag.id)}
                        onSelect={() =>
                          ($form.tag_ids = toggleSelectedTag(
                            $form.tag_ids,
                            tag.id,
                          ))}
                        class="px-3 py-2 rounded-[5px]"
                      >
                        <span class="text-fg-primary">{tag.name}</span>
                      </Command.Item>
                    {/each}
                  </Command.List>
                </Command.Root>
              </Popover.Content>
            </Popover.Root>
          {/if}

          <button
            type="button"
            class={rowButton}
            role="switch"
            aria-checked={$form.billable}
            onclick={() => ($form.billable = !$form.billable)}
          >
            <DollarSign
              class="size-4 shrink-0 {$form.billable
                ? 'text-bright-green'
                : 'text-fg-muted'}"
              aria-hidden="true"
            />
            <span class={$form.billable ? "text-bright-green" : "text-fg-muted"}
              >{$form.billable ? "Billable" : "Non-billable"}</span
            >
            <span
              class="ml-auto flex items-center w-8 h-[18px] p-0.5 rounded-full transition-colors duration-150 {$form.billable
                ? 'bg-bright-green'
                : 'bg-bg-quaternary'}"
              aria-hidden="true"
            >
              <span
                class="size-3.5 rounded-full bg-bg-primary transition-transform duration-150 {$form.billable
                  ? 'translate-x-3.5'
                  : ''}"
              ></span>
            </span>
          </button>
        </div>
      {/if}
    </div>

    <div class="flex items-center justify-end gap-2 px-4 pb-4">
      <Button type="button" variant="ghost" onclick={closeQuickEdit}>
        Cancel
      </Button>
      <Button
        type="button"
        tone="purple"
        onclick={saveQuickEntry}
        disabled={!$form.description.trim() || $form.processing}
      >
        Save
      </Button>
    </div>
  </Popover.Content>
</Popover.Root>
