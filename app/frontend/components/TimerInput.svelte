<script lang="ts">
  import {
    Play,
    Square,
    DollarSign,
    X,
    Paperclip,
    Plus,
    Hash,
    Timer,
    CalendarPlus,
    ArrowUp,
    ArrowDown,
    Coffee,
  } from "@lucide/svelte";
  import { router, useForm, page, Link } from "@inertiajs/svelte";
  import DatePicker from "./DatePicker.svelte";
  import TimeField from "./TimeField.svelte";
  import {
    formatDuration,
    formatFileSize,
    formatHours,
    parseDuration,
  } from "../lib/format";
  import { routes } from "../lib/routes";
  import { toggleSelectedTag } from "../lib/time-entry-form";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Command from "$lib/components/ui/command/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Tooltip as TooltipPrimitive } from "bits-ui";
  import { cn } from "$lib/utils.js";
  import { toast } from "svelte-sonner";
  import type { Project, RecentDescription, RunningEntry, Tag } from "../types";

  let {
    runningEntry,
    projects = [],
    tags = [],
    recentDescriptions = [],
  }: {
    runningEntry: RunningEntry | null;
    projects?: Project[];
    tags?: Tag[];
    recentDescriptions?: RecentDescription[];
  } = $props();

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);

  let form = useForm({
    description: "",
    project_id: null as number | null,
    tag_ids: [] as number[],
    billable: false,
    start_at: new Date().toISOString(),
  });

  let lastSyncedEntryId: number | null = null;
  $effect(() => {
    if (runningEntry && runningEntry.id !== lastSyncedEntryId) {
      form.description = runningEntry.description ?? "";
      form.project_id = runningEntry.project?.id ?? null;
      form.tag_ids = runningEntry.tags?.map((t: { id: number }) => t.id) ?? [];
      form.billable = runningEntry.billable ?? false;
      lastSyncedEntryId = runningEntry.id;
      sentDescription = null;
    } else if (!runningEntry && lastSyncedEntryId !== null) {
      lastSyncedEntryId = null;
    }
  });

  let mode = $state<"timer" | "manual">("timer");
  const modes = [
    {
      key: "timer",
      label: "Timer",
      icon: Timer,
      hint: "Start a timer for what you're doing now",
    },
    {
      key: "manual",
      label: "Manual",
      icon: CalendarPlus,
      hint: "Add an entry you already finished, with its start and end times",
    },
  ] as const;
  // One tooltip shared by both buttons, so moving between them swaps its
  // text in place instead of fading one out while the other fades in.
  const modeTooltip = TooltipPrimitive.createTether<(typeof modes)[number]>();
  // Toggl-style timer modes. Settings apply to the next timer; a countdown
  // target is remembered by the start time it was set for, so a timer
  // started elsewhere keeps counting up.
  type TimerKind = "up" | "down" | "pomodoro";
  type Target = { start_at: string; seconds: number; kind: TimerKind };
  const SETTINGS_KEY = "timer-settings";
  const TARGET_KEY = "timer-target";

  function stored<T>(key: string, fallback: T): T {
    try {
      const value = JSON.parse(localStorage.getItem(key) ?? "null");
      return value === null ? fallback : value;
    } catch {
      return fallback;
    }
  }

  let settings = $state({
    kind: "up" as TimerKind,
    limit: 3600,
    focus: 1500,
    rest: 300,
    sound: false,
    ...stored(SETTINGS_KEY, {}),
  });
  $effect(() => localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)));

  let target = $state<Target | null>(stored(TARGET_KEY, null));
  function setTarget(next: Target | null) {
    target = next;
    if (next) localStorage.setItem(TARGET_KEY, JSON.stringify(next));
    else localStorage.removeItem(TARGET_KEY);
  }

  const timerKinds = [
    {
      key: "up",
      shortcut: "U",
      icon: ArrowUp,
      title: "Count up from zero",
      description: "Track how long you spend on the task",
    },
    {
      key: "down",
      shortcut: "D",
      icon: ArrowDown,
      title: "Count down from set time",
      description: "Work within your set limit or block of time",
    },
    {
      key: "pomodoro",
      shortcut: "O",
      icon: null,
      title: "Pomodoro Technique",
      description: "",
    },
  ] as const;
  let currentKind = $derived(
    timerKinds.find((k) => k.key === settings.kind) ?? timerKinds[0],
  );
  let showModeMenu = $state(false);

  function handleShortcut(event: KeyboardEvent) {
    if (event.metaKey || event.ctrlKey || event.altKey || isRunning) return;
    if (isManual) return;
    const target = event.target as HTMLElement;
    if (event.repeat) return;
    if (
      target.closest(
        "input, textarea, select, [contenteditable], [role=menu], [role=listbox]",
      )
    )
      return;
    if (target.closest("[role=dialog]:not([data-timer-mode])")) return;
    const kind = timerKinds.find(
      (k) => k.shortcut === event.key.toUpperCase(),
    )?.key;
    if (!kind) return;
    event.preventDefault();
    settings.kind = kind;
  }

  function chime() {
    const audio = new AudioContext();
    [880, 1320].forEach((frequency, i) => {
      const oscillator = audio.createOscillator();
      const gain = audio.createGain();
      const at = audio.currentTime + i * 0.18;
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0.0001, at);
      gain.gain.exponentialRampToValueAtTime(0.2, at + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, at + 0.5);
      oscillator.connect(gain).connect(audio.destination);
      oscillator.start(at);
      oscillator.stop(at + 0.55);
    });
    setTimeout(() => audio.close(), 1000);
  }

  // A Pomodoro break counts down to a saved end time, so it survives
  // moving between pages.
  const BREAK_KEY = "timer-break-ends";
  let breakEndsAt = $state<number>(stored(BREAK_KEY, 0));
  let clock = $state(Date.now());
  let breakLeft = $derived(
    Math.max(0, Math.ceil((breakEndsAt - clock) / 1000)),
  );
  $effect(() => {
    if (breakEndsAt <= Date.now()) return;
    const interval = setInterval(() => {
      clock = Date.now();
      if (clock < breakEndsAt) return;
      endBreak();
      if (settings.sound) chime();
    }, 1000);
    return () => clearInterval(interval);
  });
  function startBreak() {
    clock = Date.now();
    breakEndsAt = clock + settings.rest * 1000;
    localStorage.setItem(BREAK_KEY, String(breakEndsAt));
  }
  function endBreak() {
    breakEndsAt = 0;
    localStorage.removeItem(BREAK_KEY);
  }

  function updateDuration(
    field: "limit" | "focus" | "rest",
    input: HTMLInputElement,
  ) {
    const seconds = parseDuration(input.value);
    if (seconds && seconds <= 24 * 3600) settings[field] = seconds;
    input.value = formatHours(settings[field]);
  }

  let showProjectDropdown = $state(false);
  let showTagDropdown = $state(false);
  let elapsed = $state(0);
  let descriptionInput: HTMLInputElement | null = $state(null);
  let selectedFiles: File[] = $state([]);
  let fileInput: HTMLInputElement | null = $state(null);

  const timeOfDay = (date: Date) =>
    `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;

  let manualDate = $state<Date | null>(new Date());
  let manualStart = $state(timeOfDay(new Date()));
  let manualEnd = $state(timeOfDay(new Date()));

  let manualRange = $derived.by(() => {
    if (!manualDate || !manualStart || !manualEnd) return null;
    const at = (time: string) => {
      const [hours, minutes] = time.split(":").map(Number);
      const date = new Date(manualDate!);
      date.setHours(hours, minutes, 0, 0);
      return date;
    };
    const start = at(manualStart);
    const end = at(manualEnd);
    // An end time before the start time means the entry ran past midnight.
    if (end < start) end.setDate(end.getDate() + 1);
    return { start, end };
  });

  let selectedProject = $derived(
    projects.find((p: { id: number }) => p.id === form.project_id),
  );

  let selectedTags = $derived(
    tags.filter((t: { id: number }) => form.tag_ids.includes(t.id)),
  );

  let isRunning = $derived(!!runningEntry);
  let isManual = $derived(mode === "manual" && !isRunning);

  let activeTarget = $derived(
    runningEntry &&
      target &&
      Math.abs(
        new Date(runningEntry.start_at).getTime() -
          new Date(target.start_at).getTime(),
      ) < 5000
      ? target
      : null,
  );

  let idleSeconds = $derived(
    breakLeft > 0
      ? breakLeft
      : settings.kind === "down"
        ? settings.limit
        : settings.kind === "pomodoro"
          ? settings.focus
          : 0,
  );

  let displayedSeconds = $derived(
    isManual
      ? manualRange
        ? (manualRange.end.getTime() - manualRange.start.getTime()) / 1000
        : 0
      : !isRunning
        ? idleSeconds
        : activeTarget
          ? Math.max(0, activeTarget.seconds - elapsed)
          : elapsed,
  );

  // A countdown or focus session stops its entry when time is up; a
  // finished focus session starts the break.
  let finishing = false;
  // Set from Stop until the stop request finishes, so a double tap sends one.
  let stopping = $state(false);
  $effect(() => {
    if (!activeTarget || elapsed < activeTarget.seconds || finishing) return;
    finishing = true;
    const kind = activeTarget.kind;
    if (settings.sound) chime();
    stopTimer({
      keepForm: true,
      endAt: new Date(
        new Date(activeTarget.start_at).getTime() + activeTarget.seconds * 1000,
      ),
      onDone: () => kind === "pomodoro" && startBreak(),
    });
  });

  $effect(() => {
    if (!runningEntry) {
      elapsed = 0;
      return;
    }
    const startTime = new Date(runningEntry.start_at).getTime();
    // A start slightly in the future (clock skew, another device) shows 0.
    const tick = () =>
      (elapsed = Math.max(0, Math.floor((Date.now() - startTime) / 1000)));
    tick();
    const interval = setInterval(tick, 1000);
    return () => clearInterval(interval);
  });

  function resetForm() {
    form.description = "";
    form.project_id = null;
    form.tag_ids = [];
    form.billable = false;
  }

  function startTimer() {
    if (!form.description.trim() || form.processing) return;

    endBreak();
    form.start_at = new Date().toISOString();
    setTarget(
      settings.kind === "up"
        ? null
        : {
            start_at: form.start_at,
            kind: settings.kind,
            seconds: settings.kind === "down" ? settings.limit : settings.focus,
          },
    );
    form
      .transform((data) => ({ time_entry: data }))
      .post(routes.timeEntries.create(workspaceId), {
        preserveScroll: true,
        onSuccess: () => {
          showProjectDropdown = false;
          showTagDropdown = false;
        },
      });
  }

  function addManualEntry() {
    if (
      !form.description.trim() ||
      !manualRange ||
      displayedSeconds <= 0 ||
      form.processing
    )
      return;
    const { start, end } = manualRange;

    form
      .transform((data) => ({
        time_entry: {
          ...data,
          start_at: start.toISOString(),
          end_at: end.toISOString(),
        },
      }))
      .post(routes.timeEntries.create(workspaceId), {
        preserveScroll: true,
        onSuccess: () => {
          resetForm();
          manualDate = new Date(end);
          manualStart = timeOfDay(end);
          manualEnd = timeOfDay(end);
          descriptionInput?.focus();
        },
      });
  }

  type StopOptions = { keepForm?: boolean; endAt?: Date; onDone?: () => void };

  // Pending edits are saved first. If that fails, a manual stop keeps the
  // timer running so the typed description isn't lost; a finished countdown
  // still stops, keeping its description in the form.
  function stopTimer(options: StopOptions = {}) {
    if (!runningEntry || stopping) return;
    stopping = true;
    saveDescription((saved) => {
      if (saved || options.keepForm) {
        sendStop(options);
      } else {
        stopping = false;
        finishing = false;
        toast.error(
          "Couldn't save your changes, so the timer is still running.",
        );
      }
    });
  }

  function sendStop({ keepForm = false, endAt, onDone }: StopOptions) {
    // The timer can be stopped elsewhere while its description saves.
    if (!runningEntry) {
      stopping = false;
      return;
    }

    const formData = new FormData();
    if (endAt) formData.append("time_entry[end_at]", endAt.toISOString());
    selectedFiles.forEach((file) => {
      formData.append("time_entry[files][]", file);
    });

    router.patch(
      routes.timeEntries.stop(workspaceId, runningEntry.id),
      formData,
      {
        preserveScroll: true,
        onSuccess: () => {
          selectedFiles = [];
          setTarget(null);
          if (!keepForm) resetForm();
          onDone?.();
          setTimeout(() => descriptionInput?.focus(), 100);
        },
        onFinish: () => {
          stopping = false;
          finishing = false;
        },
      },
    );
  }

  function handleFileSelect(event: Event) {
    const target = event.target as HTMLInputElement;
    if (target.files) {
      const files = Array.from(target.files);
      if (selectedFiles.length + files.length > 3) {
        toast.error("You can only attach up to 3 files");
        target.value = "";
        return;
      }
      selectedFiles = [...selectedFiles, ...files].slice(0, 3);
      target.value = "";
    }
  }

  function removeFile(index: number) {
    selectedFiles = selectedFiles.filter((_, i) => i !== index);
  }

  function selectProject(
    project: { id: number; billable_default: boolean } | null,
  ) {
    form.project_id = project?.id ?? null;
    if (project?.billable_default) form.billable = true;
    showProjectDropdown = false;
    saveRunning({ project_id: form.project_id, billable: form.billable });
  }

  function toggleTag(tagId: number) {
    form.tag_ids = toggleSelectedTag(form.tag_ids, tagId);
    saveRunning({ tag_ids: form.tag_ids });
  }

  function toggleBillable() {
    form.billable = !form.billable;
    saveRunning({ billable: form.billable });
  }

  // The running timer saves each change as it's made. The description saves
  // after a pause in typing, on Enter, or when the field loses focus. Saves
  // run in the background so they don't cancel, or get cancelled by, a visit,
  // and one at a time: changes made while one is in flight are merged into
  // the next, so an older request can't overwrite a newer change.
  let descriptionSave: ReturnType<typeof setTimeout> | undefined;
  let saveInFlight = false;
  let pendingFields: Partial<RecentDescription> = {};
  let saveFailed = false;
  let afterSaves: ((saved: boolean) => void)[] = [];
  // The description last sent to the server, which the runningEntry prop
  // lags behind while that save is in flight; null until one is sent, or
  // after one fails.
  let sentDescription: string | null = null;

  function saveRunning(
    fields: Partial<RecentDescription>,
    onSaved?: (saved: boolean) => void,
  ) {
    pendingFields = { ...pendingFields, ...fields };
    if (onSaved) afterSaves.push(onSaved);
    if (!saveInFlight) sendPendingFields();
  }

  function sendPendingFields() {
    const { tag_ids, ...fields } = pendingFields;
    pendingFields = {};
    if (!runningEntry || (!tag_ids && !Object.keys(fields).length)) {
      const callbacks = afterSaves;
      const saved = !saveFailed;
      afterSaves = [];
      saveFailed = false;
      callbacks.forEach((callback) => callback(saved));
      return;
    }
    saveInFlight = true;
    if (fields.description !== undefined) sentDescription = fields.description;
    let saved = false;
    router.patch(
      routes.timeEntries.update(workspaceId, runningEntry.id),
      {
        time_entry: {
          ...fields,
          // An empty list leaves the tags unchanged; [""] clears them.
          ...(tag_ids && { tag_ids: tag_ids.length ? tag_ids : [""] }),
        },
      },
      {
        async: true,
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => (saved = true),
        onFinish: () => {
          saveInFlight = false;
          if (!saved) {
            saveFailed = true;
            sentDescription = null;
          }
          sendPendingFields();
        },
      },
    );
  }

  function saveDescription(onSaved?: (saved: boolean) => void) {
    clearTimeout(descriptionSave);
    descriptionSave = undefined;
    const latest =
      pendingFields.description ??
      sentDescription ??
      runningEntry?.description ??
      "";
    const changed = !!runningEntry && form.description !== latest;
    saveRunning(changed ? { description: form.description } : {}, onSaved);
  }

  $effect(() => () => {
    if (descriptionSave) saveDescription();
  });

  // Suggestions from past entries; picking one fills in its details too.
  let suggestionsOpen = $state(false);
  let activeSuggestion = $state(-1);
  let suggestions = $derived.by(() => {
    const query = form.description.trim().toLowerCase();
    if (!query) return [];
    const matches = recentDescriptions.filter((recent) =>
      recent.description.toLowerCase().includes(query),
    );
    const prefix = (recent: RecentDescription) =>
      recent.description.toLowerCase().startsWith(query);
    return [
      ...matches.filter(prefix),
      ...matches.filter((recent) => !prefix(recent)),
    ].slice(0, 8);
  });
  let showSuggestions = $derived(suggestionsOpen && suggestions.length > 0);

  function pickSuggestion(recent: RecentDescription) {
    suggestionsOpen = false;
    clearTimeout(descriptionSave);
    descriptionSave = undefined;
    form.description = recent.description;
    form.project_id = projects.some((p) => p.id === recent.project_id)
      ? recent.project_id
      : null;
    form.tag_ids = recent.tag_ids.filter((id) => tags.some((t) => t.id === id));
    form.billable = recent.billable;
    saveRunning({
      description: form.description,
      project_id: form.project_id,
      tag_ids: form.tag_ids,
      billable: form.billable,
    });
  }

  function handleDescriptionInput() {
    suggestionsOpen = true;
    activeSuggestion = -1;
    if (!runningEntry) return;
    clearTimeout(descriptionSave);
    descriptionSave = setTimeout(saveDescription, 600);
  }

  function handleDescriptionKeydown(event: KeyboardEvent) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (!suggestions.length) return;
      event.preventDefault();
      const count = suggestions.length;
      if (!showSuggestions) {
        suggestionsOpen = true;
        activeSuggestion = event.key === "ArrowDown" ? 0 : count - 1;
      } else {
        const step = event.key === "ArrowDown" ? 1 : -1;
        activeSuggestion =
          activeSuggestion === -1 && step === -1
            ? count - 1
            : (activeSuggestion + step + count) % count;
      }
      return;
    }
    if (event.key === "Escape" && showSuggestions) {
      event.preventDefault();
      event.stopPropagation();
      suggestionsOpen = false;
      return;
    }
    if (event.key !== "Enter") return;
    if (showSuggestions && activeSuggestion >= 0) {
      event.preventDefault();
      pickSuggestion(suggestions[activeSuggestion]);
      return;
    }
    suggestionsOpen = false;
    if (isRunning) {
      event.preventDefault();
      saveDescription();
      return;
    }
    if (!form.description.trim()) return;
    event.preventDefault();
    if (isManual) {
      addManualEntry();
    } else {
      startTimer();
    }
  }

  const iconButton =
    "inline-flex items-center justify-center size-8 shrink-0 rounded-lg text-fg-dim hover:text-fg-primary hover:bg-bg-tertiary transition-colors duration-150 disabled:pointer-events-none data-[state=open]:bg-bg-tertiary data-[state=open]:text-fg-primary";
  // Toggl-style pickers: dashed while empty, solid once something is picked.
  // Every control in the bar is 32px tall; the icon tile sits 4px inside an 8px corner.
  const chipButton =
    "inline-flex items-center gap-1.5 h-8 pl-1 pr-2.5 rounded-lg border text-sm font-medium transition-colors duration-150 disabled:pointer-events-none data-[state=open]:border-solid data-[state=open]:border-bright-blue";
  const chipEmpty =
    "border-dashed border-bg-quaternary text-fg-muted hover:text-fg-primary hover:border-fg-dim";
  const chipFilled = "border-bg-tertiary bg-bg-primary text-fg-primary";
  const chipIcon =
    "grid place-items-center size-6 shrink-0 rounded-[4px] bg-bg-tertiary text-fg-secondary";
</script>

<svelte:window onkeydown={handleShortcut} />

{#snippet tomato(className: string)}
  <svg
    viewBox="0 0 24 24"
    class={className}
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path
      d="M12 8c-5 0-9 2.6-9 6.2C3 17.9 7 21 12 21s9-3.1 9-6.8C21 10.6 17 8 12 8Z"
      fill="currentColor"
      fill-opacity="0.2"
    />
    <path d="M12 8 9 5.5M12 8l3-2.5M12 8l-4.5.5M12 8l4.5.5M12 8V4.5" />
  </svg>
{/snippet}

{#snippet durationRow(label: string, field: "limit" | "focus" | "rest")}
  <label class="flex items-center justify-between gap-3">
    <span>{label}</span>
    <input
      type="text"
      value={formatHours(settings[field])}
      class="w-20 h-8 rounded-lg border border-bg-tertiary bg-bg-primary text-center font-tabular outline-none focus:border-bright-purple transition-colors"
      onchange={(e) => updateDuration(field, e.currentTarget)}
      onkeydown={(e) => e.key === "Enter" && e.currentTarget.blur()}
    />
  </label>
{/snippet}

<div
  class="bg-bg-secondary border-b border-bg-tertiary px-4 md:px-6 py-2.5 md:py-3"
  role="region"
  aria-label="Time tracker"
>
  <div
    class="flex flex-col md:flex-row md:flex-wrap md:items-center gap-x-4 gap-y-2"
  >
    <label for="timer-description" class="sr-only"
      >{isManual ? "What did you work on?" : "What are you working on?"}</label
    >
    <div class="relative flex-1 min-w-0 md:min-w-60">
      <input
        id="timer-description"
        bind:value={form.description}
        bind:this={descriptionInput}
        placeholder={isManual
          ? "What did you work on?"
          : "What are you working on?"}
        role="combobox"
        aria-autocomplete="list"
        aria-expanded={showSuggestions}
        aria-controls="timer-suggestions"
        aria-activedescendant={showSuggestions && activeSuggestion >= 0
          ? `timer-suggestion-${activeSuggestion}`
          : undefined}
        oninput={handleDescriptionInput}
        onkeydown={handleDescriptionKeydown}
        onblur={() => {
          suggestionsOpen = false;
          saveDescription();
        }}
        class="w-full bg-transparent text-base md:text-lg font-extrabold text-fg-primary placeholder:font-bold placeholder:text-fg-muted outline-none h-9"
        autocomplete="off"
      />
      {#if showSuggestions}
        <ul
          id="timer-suggestions"
          role="listbox"
          aria-label="Past entries"
          class="absolute left-0 top-full z-50 mt-1 w-full max-w-md p-1 rounded-[10px] border border-border bg-popover text-popover-foreground text-sm shadow-lg"
        >
          {#each suggestions as recent, i (recent.description)}
            {@const project = projects.find((p) => p.id === recent.project_id)}
            <!-- The input keeps focus and handles the keyboard. -->
            <!-- svelte-ignore a11y_click_events_have_key_events -->
            <li
              id="timer-suggestion-{i}"
              role="option"
              aria-selected={i === activeSuggestion}
              class="flex items-center gap-3 px-3 py-2 rounded-[5px] cursor-pointer {i ===
              activeSuggestion
                ? 'bg-muted'
                : ''}"
              onpointerdown={(e) => e.preventDefault()}
              onpointermove={() => (activeSuggestion = i)}
              onclick={() => pickSuggestion(recent)}
            >
              <span class="flex-1 min-w-0 truncate text-fg-primary"
                >{recent.description}</span
              >
              {#if project}
                <span
                  class="flex items-center gap-1.5 min-w-0 max-w-40 text-fg-secondary"
                >
                  <span
                    class="size-2 shrink-0 rounded-full"
                    style="background-color: {project.color}"
                    aria-hidden="true"
                  ></span>
                  <span class="truncate">{project.name}</span>
                </span>
              {/if}
              {#if recent.billable}
                <DollarSign
                  class="size-3.5 shrink-0 text-bright-green"
                  aria-label="Billable"
                />
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    </div>

    <div class="flex items-center gap-1.5 flex-wrap lg:ml-auto max-lg:w-full">
      <Popover.Root bind:open={showProjectDropdown}>
        <Popover.Trigger>
          {#snippet child({ props })}
            <button
              {...props}
              type="button"
              class="{chipButton} {selectedProject
                ? chipFilled
                : chipEmpty} max-w-56"
              aria-label={selectedProject
                ? `Project: ${selectedProject.name}`
                : "Select project"}
              title={selectedProject ? selectedProject.name : "Project"}
            >
              <span class={chipIcon} aria-hidden="true">
                {#if selectedProject}
                  <span
                    class="size-2.5 rounded-full"
                    style="background-color: {selectedProject.color}"
                  ></span>
                {:else}
                  <Plus class="size-3.5" />
                {/if}
              </span>
              <span class="truncate"
                >{selectedProject ? selectedProject.name : "Project"}</span
              >
            </button>
          {/snippet}
        </Popover.Trigger>
        <Popover.Content align="end" class="w-64 p-0">
          {#if projects.length === 0}
            <p class="p-3 text-fg-muted text-sm">
              No projects yet. <Link
                href={routes.projects.index(workspaceId)}
                class="text-bright-blue hover:underline">Create one</Link
              >.
            </p>
          {:else}
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
                    data-checked={form.project_id === project.id}
                    onSelect={() => selectProject(project)}
                    class="gap-3 px-3 py-2 rounded-[5px]"
                  >
                    <span
                      class="w-3 h-3 rounded-full shrink-0"
                      style="background-color: {project.color}"
                      aria-hidden="true"
                    ></span>
                    <div class="flex-1 min-w-0">
                      <p class="text-fg-primary truncate">{project.name}</p>
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
          {/if}
        </Popover.Content>
      </Popover.Root>

      <Popover.Root bind:open={showTagDropdown}>
        <Popover.Trigger>
          {#snippet child({ props })}
            <button
              {...props}
              type="button"
              class="{chipButton} {selectedTags.length > 0
                ? chipFilled
                : chipEmpty} max-w-56"
              aria-label={selectedTags.length > 0
                ? `Tags: ${selectedTags.map((t: { name: string }) => t.name).join(", ")}`
                : "Select tags"}
              title={selectedTags.length > 0
                ? selectedTags.map((t: { name: string }) => t.name).join(", ")
                : "Tags"}
            >
              <span class={chipIcon} aria-hidden="true">
                <Hash class="size-3.5" />
              </span>
              <span class="truncate"
                >{selectedTags.length > 0
                  ? selectedTags.map((t: { name: string }) => t.name).join(", ")
                  : "Tags"}</span
              >
            </button>
          {/snippet}
        </Popover.Trigger>
        <Popover.Content align="end" class="w-56 p-0">
          {#if tags.length === 0}
            <p class="p-3 text-fg-muted text-sm">
              No tags yet. <Link
                href={routes.tags.index(workspaceId)}
                class="text-bright-blue hover:underline">Create one</Link
              >.
            </p>
          {:else}
            <Command.Root>
              <Command.Input placeholder="Search tags..." />
              <Command.List>
                <Command.Empty>No matching tags.</Command.Empty>
                {#each tags as tag (tag.id)}
                  <Command.Item
                    value={tag.name}
                    data-checked={form.tag_ids.includes(tag.id)}
                    onSelect={() => toggleTag(tag.id)}
                    class="px-3 py-2 rounded-[5px]"
                  >
                    <span class="text-fg-primary">{tag.name}</span>
                  </Command.Item>
                {/each}
              </Command.List>
            </Command.Root>
          {/if}
        </Popover.Content>
      </Popover.Root>

      <button
        type="button"
        class={cn(
          iconButton,
          form.billable &&
            "bg-bright-green/15 text-bright-green hover:bg-bright-green/25 hover:text-bright-green",
        )}
        aria-pressed={form.billable}
        aria-label="Billable"
        title={form.billable ? "Billable" : "Non-billable"}
        onclick={toggleBillable}
      >
        <DollarSign class="w-4 h-4" aria-hidden="true" />
      </button>

      {#if runningEntry}
        <input
          bind:this={fileInput}
          type="file"
          multiple
          accept="*/*"
          class="hidden"
          onchange={handleFileSelect}
        />
        <button
          type="button"
          onclick={() => fileInput?.click()}
          disabled={selectedFiles.length >= 3}
          class="{iconButton} relative"
          aria-label="Attach files"
          title="Attach files"
        >
          <Paperclip class="w-4 h-4" aria-hidden="true" />
          {#if selectedFiles.length > 0}
            <span
              class="absolute -top-0.5 -right-0.5 w-4 h-4 bg-bright-blue text-bg-primary text-xs font-medium rounded-full flex items-center justify-center"
            >
              {selectedFiles.length}
            </span>
          {/if}
        </button>
      {/if}

      {#if isManual}
        <div class="flex items-center gap-1 text-sm">
          <TimeField label="Start time" bind:value={manualStart} />
          <span class="text-fg-dim" aria-hidden="true">–</span>
          <TimeField label="End time" bind:value={manualEnd} />
          <DatePicker
            id="manual-date"
            bind:value={manualDate}
            max={new Date()}
            format={(date) =>
              date.toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
              })}
            class="w-auto h-8 gap-1.5 px-2 rounded-lg border-transparent bg-transparent hover:bg-bg-tertiary hover:border-transparent data-[state=open]:border-transparent data-[state=open]:bg-bg-tertiary"
          />
        </div>
      {/if}

      <div class="flex items-center gap-2 ml-auto lg:ml-3">
        {#if !isManual}
          <Popover.Root bind:open={showModeMenu}>
            <Popover.Trigger disabled={isRunning}>
              {#snippet child({ props })}
                <button
                  {...props}
                  type="button"
                  class={cn(
                    iconButton,
                    settings.kind !== "up" &&
                      "bg-bright-purple/15 text-bright-purple hover:bg-bright-purple/25 hover:text-bright-purple data-[state=open]:bg-bright-purple/25 data-[state=open]:text-bright-purple",
                    breakLeft > 0 &&
                      !isRunning &&
                      "bg-bright-green/15 text-bright-green hover:bg-bright-green/25 hover:text-bright-green",
                  )}
                  aria-label={breakLeft > 0 && !isRunning
                    ? "On a break. Timer mode: Pomodoro Technique"
                    : `Timer mode: ${currentKind.title}`}
                  title={breakLeft > 0 && !isRunning
                    ? "Break"
                    : currentKind.title}
                >
                  {#if breakLeft > 0 && !isRunning}
                    <Coffee class="size-4" aria-hidden="true" />
                  {:else if settings.kind === "pomodoro"}
                    {@render tomato("size-4")}
                  {:else}
                    <currentKind.icon class="size-4" aria-hidden="true" />
                  {/if}
                </button>
              {/snippet}
            </Popover.Trigger>
            <Popover.Content
              align="end"
              class="w-72 p-0 gap-0"
              data-timer-mode
              onOpenAutoFocus={(event) => {
                event.preventDefault();
                requestAnimationFrame(() =>
                  document
                    .querySelector<HTMLElement>(
                      "[data-timer-mode] [aria-checked=true]",
                    )
                    ?.focus(),
                );
              }}
            >
              <div
                class="m-1 grid grid-cols-3 rounded-[5px] border border-bg-tertiary overflow-hidden divide-x divide-bg-tertiary"
                role="radiogroup"
                aria-label="Timer mode"
                tabindex="-1"
                onkeydown={(event) => {
                  const step =
                    event.key === "ArrowRight"
                      ? 1
                      : event.key === "ArrowLeft"
                        ? -1
                        : 0;
                  if (!step) return;
                  event.preventDefault();
                  const index = timerKinds.indexOf(currentKind);
                  settings.kind = timerKinds[(index + step + 3) % 3].key;
                  const cells = event.currentTarget.querySelectorAll("button");
                  cells[(index + step + 3) % 3].focus();
                }}
              >
                {#each timerKinds as option (option.key)}
                  <button
                    type="button"
                    role="radio"
                    aria-checked={settings.kind === option.key}
                    aria-label={option.title}
                    tabindex={settings.kind === option.key ? 0 : -1}
                    class="grid place-items-center h-8 outline-none focus-visible:shadow-[inset_0_0_0_2px_var(--color-bright-purple)]! transition-colors duration-150 {settings.kind ===
                    option.key
                      ? 'bg-bright-purple/15 text-bright-purple'
                      : 'text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary'}"
                    onclick={() => (settings.kind = option.key)}
                  >
                    {#if option.icon}
                      <option.icon class="size-4" aria-hidden="true" />
                    {:else}
                      {@render tomato("size-4")}
                    {/if}
                  </button>
                {/each}
              </div>
              <div class="px-3 pt-2 pb-3 space-y-3">
                <div>
                  <p class="flex items-center gap-2 font-semibold">
                    {currentKind.title}
                    <kbd
                      class="grid place-items-center min-w-5 h-5 px-1 rounded bg-bg-tertiary font-sans text-xs font-medium text-fg-secondary"
                      >{currentKind.shortcut}</kbd
                    >
                  </p>
                  {#if settings.kind === "pomodoro"}
                    <ul
                      class="mt-1 list-disc pl-5 text-fg-muted space-y-0.5 marker:text-fg-dim"
                    >
                      <li>Work in focused sprints</li>
                      <li>Take short breaks to recharge</li>
                      <li>Repeat to maintain momentum</li>
                    </ul>
                  {:else}
                    <p class="mt-1 text-fg-muted text-pretty">
                      {currentKind.description}
                    </p>
                  {/if}
                </div>
                {#if settings.kind === "down"}
                  {@render durationRow("Time limit", "limit")}
                {:else if settings.kind === "pomodoro"}
                  {@render durationRow("Focus session", "focus")}
                  {@render durationRow("Short break", "rest")}
                {/if}
                {#if settings.kind !== "up"}
                  <div class="flex items-center justify-between gap-3">
                    <span id="timer-sound-label">Sound when time is up</span>
                    <button
                      type="button"
                      role="switch"
                      aria-checked={settings.sound}
                      aria-labelledby="timer-sound-label"
                      class="relative w-9 h-5 shrink-0 rounded-full transition-colors duration-150 {settings.sound
                        ? 'bg-bright-purple'
                        : 'bg-bg-quaternary'}"
                      onclick={() => {
                        settings.sound = !settings.sound;
                        if (settings.sound) chime();
                      }}
                    >
                      <span
                        class="absolute top-0.5 left-0.5 size-4 rounded-full bg-white shadow-sm transition-transform duration-150 {settings.sound
                          ? 'translate-x-4'
                          : ''}"
                      ></span>
                    </button>
                  </div>
                {/if}
              </div>
            </Popover.Content>
          </Popover.Root>
        {/if}

        <span
          class="text-xl leading-8 font-tabular font-semibold min-w-20 text-right {breakLeft >
            0 && !isRunning
            ? 'text-bright-green'
            : 'text-fg-primary'}"
          role="timer"
          aria-live="off"
          aria-label={isRunning ? "Elapsed time" : "Duration"}
        >
          {formatDuration(displayedSeconds)}
        </span>

        {#if runningEntry}
          <button
            onclick={() => stopTimer()}
            disabled={stopping}
            class="size-9 shrink-0 grid place-items-center rounded-full bg-bright-red hover:bg-accent-red text-bg-primary transition-colors duration-150 disabled:opacity-50"
            aria-label="Stop timer"
          >
            <Square class="w-3.5 h-3.5 fill-current" aria-hidden="true" />
          </button>
        {:else if isManual}
          <button
            onclick={addManualEntry}
            disabled={!form.description.trim() ||
              displayedSeconds <= 0 ||
              form.processing}
            class="h-9 shrink-0 px-4 rounded-full bg-bright-purple hover:bg-accent-purple text-bg-primary text-sm font-semibold transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Add
          </button>
        {:else}
          <button
            onclick={startTimer}
            disabled={!form.description.trim() || form.processing}
            class="size-9 shrink-0 grid place-items-center rounded-full bg-bright-purple hover:bg-accent-purple text-bg-primary transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
            aria-label="Start timer"
          >
            <Play class="w-4 h-4 ml-0.5 fill-current" aria-hidden="true" />
          </button>
        {/if}

        {#if !isRunning}
          <!-- Stacked like Toggl's switch: 44px tall, but -my-1 keeps the
               bar's row at 36px. On phones it lies flat for bigger targets. -->
          <Tooltip.Provider delayDuration={0}>
            <div
              class="flex flex-col w-8 h-11 -my-1 p-0.5 gap-0.5 ml-1 rounded-lg bg-bg-primary border border-bg-tertiary max-md:flex-row max-md:w-auto max-md:h-9 max-md:my-0"
              role="radiogroup"
              aria-label="Entry mode"
            >
              {#each modes as option (option.key)}
                <Tooltip.Trigger tether={modeTooltip} payload={option}>
                  {#snippet child({ props })}
                    <button
                      {...props}
                      type="button"
                      role="radio"
                      aria-checked={mode === option.key}
                      aria-label={option.label}
                      onclick={() => (mode = option.key)}
                      class="flex-1 grid place-items-center rounded-[5px] max-md:w-[30px] transition-colors duration-150 {mode ===
                      option.key
                        ? 'bg-bright-purple/15 text-bright-purple'
                        : 'text-fg-dim hover:text-fg-primary'}"
                    >
                      <option.icon class="size-3.5" aria-hidden="true" />
                    </button>
                  {/snippet}
                </Tooltip.Trigger>
              {/each}
            </div>
            <Tooltip.Root tether={modeTooltip}>
              {#snippet children({ payload })}
                <Tooltip.Content
                  side="left"
                  sideOffset={6}
                  class="flex-col items-start gap-0.5 max-w-56"
                >
                  <span class="font-semibold">{payload?.label}</span>
                  <span>{payload?.hint}</span>
                </Tooltip.Content>
              {/snippet}
            </Tooltip.Root>
          </Tooltip.Provider>
        {/if}
      </div>
    </div>
  </div>

  {#if runningEntry && selectedFiles.length > 0}
    <div class="border-t border-bg-tertiary pt-3 mt-3">
      <div class="flex flex-wrap gap-2">
        {#each selectedFiles as file, index}
          <div
            class="flex items-center gap-2 px-3 py-1.5 bg-bg-primary border border-bg-tertiary rounded-lg text-sm"
          >
            <span class="truncate max-w-37.5">{file.name}</span>
            <span class="text-fg-muted text-xs"
              >({formatFileSize(file.size)})</span
            >
            <button
              type="button"
              onclick={() => removeFile(index)}
              class="p-1 text-fg-muted hover:text-bright-red rounded transition-colors"
              aria-label="Remove file"
            >
              <X class="w-3 h-3" />
            </button>
          </div>
        {/each}
      </div>
    </div>
  {/if}
</div>
