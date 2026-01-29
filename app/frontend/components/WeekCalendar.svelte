<script lang="ts">
  import {
    ChevronLeft,
    ChevronRight,
    Calendar as CalendarIcon,
  } from "lucide-svelte";
  import { router, useForm, page } from "@inertiajs/svelte";

  let { entries = [], projects = [], currentWeek } = $props();
  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  let form = useForm({
    description: "",
    project_id: null as number | null,
    billable: false,
    start_at: null as string | null,
    end_at: null as string | null,
  });

  let startHour = 6;
  let endHour = 22;
  let hourHeight = 60;
  let isDragging = $state(false);
  let dragStart = $state(null as { hour: number; minute: number } | null);
  let dragCurrent = $state(null as { hour: number; minute: number } | null);
  let dragDay = $state(null as Date | null);
  let showQuickEdit = $state(false);

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

  function formatISODate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function goToWeek(offsetWeeks: number) {
    const start = new Date(`${currentWeek.start}T00:00:00`);
    start.setDate(start.getDate() + offsetWeeks * 7);

    router.get(
      "/calendar",
      { week_start: formatISODate(start) },
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

  function getEntriesForDay(date: Date) {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);

    return entries.filter(
      (entry: { start_at: string; end_at: string | null }) => {
        const entryStart = new Date(entry.start_at);
        return entryStart >= startOfDay && entryStart <= endOfDay;
      },
    );
  }

  function getEntryStyle(entry: {
    start_at: string;
    end_at: string | null;
    duration_seconds: number | null;
  }) {
    const start = new Date(entry.start_at);
    const startMinutes = start.getHours() * 60 + start.getMinutes();
    const minutesFromStart = startMinutes - startHour * 60;
    const top = (minutesFromStart / 60) * hourHeight;

    let duration = entry.duration_seconds;
    if (!duration && entry.end_at) {
      const end = new Date(entry.end_at);
      duration = (end.getTime() - start.getTime()) / 1000;
    }
    const height = ((duration || 3600) / 3600) * hourHeight;

    return `top: ${top}px; height: ${Math.max(height, 20)}px;`;
  }

  function getDayTotal(date: Date) {
    const dayEntries = getEntriesForDay(date);
    let totalSeconds = 0;
    dayEntries.forEach(
      (entry: {
        duration_seconds: number | null;
        end_at: string | null;
        start_at: string;
      }) => {
        if (entry.duration_seconds) {
          totalSeconds += entry.duration_seconds;
        } else if (entry.end_at) {
          const start = new Date(entry.start_at);
          const end = new Date(entry.end_at);
          totalSeconds += (end.getTime() - start.getTime()) / 1000;
        }
      },
    );
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

    showQuickEdit = true;
    isDragging = false;
    dragStart = null;
    dragCurrent = null;
    dragDay = null;
  }

  function saveQuickEntry() {
    if (!$form.description.trim()) return;

    $form.post(`/${workspaceId}/time_entries`, {
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

  function formatTimeRange() {
    if (!$form.start_at || !$form.end_at) return "";
    const start = new Date($form.start_at);
    const end = new Date($form.end_at);
    return `${start.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })} - ${end.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })}`;
  }

  function selectProject(project: { id: number; billable_default: boolean }) {
    $form.project_id = project.id;
    if (project.billable_default) {
      $form.billable = true;
    }
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
      <button
        type="button"
        class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
        aria-label="Previous week"
        onclick={() => goToWeek(-1)}
      >
        <ChevronLeft class="w-5 h-5" />
      </button>
      <span
        class="px-4 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] font-medium min-w-50 text-center"
      >
        {currentWeek.start} - {currentWeek.end}
      </span>
      <button
        type="button"
        class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
        aria-label="Next week"
        onclick={() => goToWeek(1)}
      >
        <ChevronRight class="w-5 h-5" />
      </button>
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
              <div
                class="absolute left-1 right-1 rounded-md px-2 py-1 text-xs overflow-hidden cursor-pointer hover:brightness-110 transition-all duration-200"
                style="{getEntryStyle(entry)} background-color: {entry.project
                  ?.color || '#b16286'}40; border-left: 3px solid {entry.project
                  ?.color || '#b16286'};"
                title="{entry.description ||
                  'No description'} ({entry.formattedDuration})"
              >
                <div class="font-medium truncate text-fg-primary">
                  {entry.description || "No description"}
                </div>
                <div class="text-fg-secondary truncate">
                  {entry.formattedDuration}
                </div>
              </div>
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

{#if showQuickEdit}
  <div
    class="fixed inset-0 bg-bg-primary/80 z-50 flex items-center justify-center p-4"
    role="presentation"
  >
    <button
      type="button"
      class="absolute inset-0 w-full h-full"
      onclick={() => (showQuickEdit = false)}
      aria-label="Close modal"
    ></button>
    <div
      class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-6 w-full max-w-md space-y-4 relative z-10"
      role="dialog"
      aria-modal="true"
      aria-labelledby="quick-edit-title"
    >
      <h3 id="quick-edit-title" class="text-xl font-semibold">
        New Time Entry
      </h3>
      <p class="text-fg-muted text-sm">{formatTimeRange()}</p>

      <div>
        <label for="entry-description" class="block text-sm font-medium mb-2"
          >Description</label
        >
        <input
          id="entry-description"
          type="text"
          placeholder="What did you work on?"
          bind:value={$form.description}
          class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-3 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue"
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

      <div class="flex items-center justify-between">
        <button
          type="button"
          onclick={() => ($form.billable = !$form.billable)}
          class="flex items-center gap-2 px-4 py-2 rounded-[10px] border transition-colors duration-150 {$form.billable
            ? 'bg-bright-green/20 border-bright-green text-bright-green'
            : 'border-bg-tertiary text-fg-muted'}"
        >
          <span>Billable</span>
        </button>

        <div class="flex gap-2">
          <button
            type="button"
            onclick={() => (showQuickEdit = false)}
            class="px-4 py-2 border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
          >
            Cancel
          </button>
          <button
            type="button"
            onclick={saveQuickEntry}
            disabled={!$form.description.trim()}
            class="px-4 py-2 bg-bright-blue hover:bg-accent-blue text-bg-primary rounded-[10px] transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Save Entry
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
