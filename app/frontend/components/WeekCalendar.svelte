<script lang="ts">
  import { DollarSign, Timer } from "lucide-svelte";
  import { useForm, page } from "@inertiajs/svelte";
  import Modal from "./Modal.svelte";
  import Button from "./Button.svelte";
  import ChipButton from "./ChipButton.svelte";
  import TextInput from "./TextInput.svelte";
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

  // Drag on an empty part of a day to add an entry for that time.
  let drag = $state<{ day: Date; from: number; to: number } | null>(null);
  let showQuickEdit = $state(false);
  let descriptionInput: HTMLInputElement | null = $state(null);
  $effect(() => {
    if (showQuickEdit && descriptionInput) {
      const input = descriptionInput;
      setTimeout(() => input.focus(), 50);
    }
  });

  let form = useForm({
    description: "",
    project_id: null as number | null,
    tag_ids: [] as number[],
    billable: false,
    start_at: null as string | null,
    end_at: null as string | null,
  });

  function minuteAt(event: PointerEvent, column: HTMLElement) {
    const y = event.clientY - column.getBoundingClientRect().top;
    const minute = Math.round(y / pxPerMinute / 15) * 15;
    return Math.max(0, Math.min(DAY_MINUTES, minute));
  }

  let dragColumn: HTMLElement | null = null;
  function startDrag(event: PointerEvent, day: Date) {
    if (event.button !== 0 || event.pointerType === "touch") return;
    dragColumn = event.currentTarget as HTMLElement;
    const minute = Math.floor(minuteAt(event, dragColumn) / 15) * 15;
    drag = { day, from: minute, to: minute };
  }

  function moveDrag(event: PointerEvent) {
    if (drag && dragColumn && !showQuickEdit)
      drag.to = minuteAt(event, dragColumn);
  }

  function endDrag() {
    if (!drag || showQuickEdit) return;
    let from = Math.min(drag.from, drag.to);
    let to = Math.max(drag.from, drag.to);
    if (to - from < 15) to = Math.min(DAY_MINUTES, from + 30);
    drag.from = from;
    drag.to = to;
    const at = (minute: number) => {
      const date = new Date(drag!.day);
      date.setHours(0, minute, 0, 0);
      return date.toISOString();
    };
    $form.start_at = at(from);
    $form.end_at = at(to);
    $form.description = "";
    $form.project_id = null;
    $form.tag_ids = [];
    $form.billable = false;
    dragColumn = null;
    showQuickEdit = true;
  }

  let dragRange = $derived(
    drag
      ? { from: Math.min(drag.from, drag.to), to: Math.max(drag.from, drag.to) }
      : null,
  );

  function saveQuickEntry() {
    if (!$form.description.trim()) return;
    $form
      .transform((data) => ({ time_entry: data }))
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
    drag = null;
  }

  const clock = (minute: number) => {
    const date = new Date(0, 0, 1, 0, minute);
    return date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
    });
  };

  function formatTimeRange() {
    if (!$form.start_at || !$form.end_at) return "";
    const time = (iso: string) =>
      new Date(iso).toLocaleTimeString("en-US", {
        hour: "numeric",
        minute: "2-digit",
      });
    const day = new Date($form.start_at).toLocaleDateString("en-US", {
      weekday: "long",
      month: "short",
      day: "numeric",
    });
    return `${day}, ${time($form.start_at)} – ${time($form.end_at)}`;
  }

  function selectProject(project: { id: number; billable_default: boolean }) {
    $form.project_id = project.id;
    if (project.billable_default) $form.billable = true;
  }
</script>

<svelte:window
  onpointermove={moveDrag}
  onpointerup={endDrag}
  onpointercancel={() => !showQuickEdit && (drag = null)}
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

          {#if dragRange && drag?.day.getTime() === day.getTime()}
            <div
              class="absolute inset-x-[3px] overflow-hidden rounded-md border-2 border-dashed border-bright-purple bg-bright-purple/15 px-1.5 py-0.5 text-xs font-medium text-bright-purple font-tabular pointer-events-none"
              style="top: {dragRange.from * pxPerMinute}px; height: {Math.max(
                dragRange.to - dragRange.from,
                15,
              ) * pxPerMinute}px;"
            >
              {clock(dragRange.from)} – {clock(
                Math.max(dragRange.to, dragRange.from + 15),
              )}
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

<Modal
  open={showQuickEdit}
  title="New Time Entry"
  onclose={closeQuickEdit}
  maxWidth="max-w-md"
>
  <p class="text-fg-muted text-sm">{formatTimeRange()}</p>

  <div>
    <label for="entry-description" class="block text-sm font-medium mb-2"
      >Description</label
    >
    <TextInput
      id="entry-description"
      type="text"
      placeholder="What did you work on?"
      bind:value={$form.description}
      bind:inputRef={descriptionInput}
      tone="blue"
      onkeydown={(e: KeyboardEvent) => e.key === "Enter" && saveQuickEntry()}
    />
  </div>

  {#if projects.length > 0}
    <div>
      <span class="block text-sm font-medium mb-2">Project</span>
      <div class="flex flex-wrap gap-2">
        {#each projects as project}
          <ChipButton
            type="button"
            selected={$form.project_id === project.id}
            class={$form.project_id === project.id
              ? "border-bright-purple text-fg-primary"
              : "text-fg-muted hover:text-fg-primary"}
            onclick={() => selectProject(project)}
          >
            <span
              class="size-2 rounded-full"
              style="background-color: {project.color}"
            ></span>
            {project.name}
          </ChipButton>
        {/each}
      </div>
    </div>
  {/if}

  {#if tags.length > 0}
    <div>
      <span class="block text-sm font-medium mb-2">Tags</span>
      <div class="flex flex-wrap gap-2">
        {#each tags as tag}
          <ChipButton
            type="button"
            selected={$form.tag_ids.includes(tag.id)}
            class={$form.tag_ids.includes(tag.id)
              ? "border-bright-purple text-fg-primary"
              : "text-fg-muted hover:text-fg-primary"}
            onclick={() =>
              ($form.tag_ids = toggleSelectedTag($form.tag_ids, tag.id))}
          >
            {tag.name}
          </ChipButton>
        {/each}
      </div>
    </div>
  {/if}

  {#snippet footer()}
    <div class="flex items-center justify-between">
      <ChipButton
        type="button"
        selected={$form.billable}
        class="h-9 {$form.billable
          ? 'border-bright-green text-bright-green'
          : 'text-fg-muted hover:text-fg-primary'}"
        onclick={() => ($form.billable = !$form.billable)}
      >
        <DollarSign class="size-4" aria-hidden="true" /> Billable
      </ChipButton>
      <div class="flex gap-2">
        <Button type="button" variant="secondary" onclick={closeQuickEdit}>
          Cancel
        </Button>
        <Button
          type="button"
          tone="purple"
          onclick={saveQuickEntry}
          disabled={!$form.description.trim() || $form.processing}
        >
          Add entry
        </Button>
      </div>
    </div>
  {/snippet}
</Modal>
