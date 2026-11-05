<script lang="ts">
  import {
    Play,
    Square,
    DollarSign,
    X,
    Paperclip,
    Folder,
    Tag,
    CirclePlay,
    CirclePlus,
  } from "lucide-svelte";
  import { router, useForm, page, Link } from "@inertiajs/svelte";
  import DatePicker from "./DatePicker.svelte";
  import { formatDuration, formatFileSize } from "../lib/format";
  import { routes } from "../lib/routes";
  import { toggleSelectedTag } from "../lib/time-entry-form";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Command from "$lib/components/ui/command/index.js";

  let { runningEntry, projects = [], tags = [] } = $props();

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

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
      $form.description = runningEntry.description ?? "";
      $form.project_id = runningEntry.project?.id ?? null;
      $form.tag_ids = runningEntry.tags?.map((t: { id: number }) => t.id) ?? [];
      $form.billable = runningEntry.billable ?? false;
      lastSyncedEntryId = runningEntry.id;
    } else if (!runningEntry && lastSyncedEntryId !== null) {
      lastSyncedEntryId = null;
    }
  });

  let mode = $state<"timer" | "manual">("timer");
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
    projects.find((p: { id: number }) => p.id === $form.project_id),
  );

  let selectedTags = $derived(
    tags.filter((t: { id: number }) => $form.tag_ids.includes(t.id)),
  );

  let isRunning = $derived(!!runningEntry);
  let isManual = $derived(mode === "manual" && !isRunning);

  let displayedSeconds = $derived(
    isManual && manualRange
      ? (manualRange.end.getTime() - manualRange.start.getTime()) / 1000
      : elapsed,
  );

  $effect(() => {
    if (!runningEntry) {
      elapsed = 0;
      return;
    }
    const startTime = new Date(runningEntry.start_at).getTime();
    const tick = () => (elapsed = Math.floor((Date.now() - startTime) / 1000));
    tick();
    const interval = setInterval(tick, 1000);
    return () => clearInterval(interval);
  });

  function resetForm() {
    $form.description = "";
    $form.project_id = null;
    $form.tag_ids = [];
    $form.billable = false;
  }

  function startTimer() {
    if (!$form.description.trim()) return;

    $form.start_at = new Date().toISOString();
    $form
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
    if (!$form.description.trim() || !manualRange || displayedSeconds <= 0)
      return;
    const { start, end } = manualRange;

    $form
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
          manualStart = timeOfDay(end);
          manualEnd = timeOfDay(end);
          descriptionInput?.focus();
        },
      });
  }

  function stopTimer() {
    if (!runningEntry) return;

    const formData = new FormData();
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
          resetForm();
          setTimeout(() => descriptionInput?.focus(), 100);
        },
      },
    );
  }

  function handleFileSelect(event: Event) {
    const target = event.target as HTMLInputElement;
    if (target.files) {
      const files = Array.from(target.files);
      if (selectedFiles.length + files.length > 3) {
        alert("You can only attach up to 3 files");
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
    $form.project_id = project?.id ?? null;
    if (project?.billable_default) $form.billable = true;
    showProjectDropdown = false;
  }

  function toggleTag(tagId: number) {
    $form.tag_ids = toggleSelectedTag($form.tag_ids, tagId);
  }

  function handleDescriptionKeydown(event: KeyboardEvent) {
    if (event.key !== "Enter" || isRunning || !$form.description.trim()) return;
    event.preventDefault();
    if (isManual) {
      addManualEntry();
    } else {
      startTimer();
    }
  }

  const iconButton =
    "inline-flex items-center gap-1.5 p-2 rounded-[10px] text-fg-dim hover:text-fg-primary hover:bg-bg-tertiary transition-colors duration-150 disabled:pointer-events-none data-[state=open]:bg-bg-tertiary data-[state=open]:text-fg-primary";
  const timeField =
    "bg-transparent text-fg-primary font-tabular scheme-dark px-2 py-1.5 rounded-[10px] hover:bg-bg-tertiary focus:bg-bg-tertiary outline-none transition-colors duration-150";
</script>

<div
  class="bg-bg-secondary border-b border-bg-tertiary px-4 md:px-6 py-3 md:py-4"
  role="region"
  aria-label="Time tracker"
>
  <div class="flex flex-col md:flex-row md:items-center gap-2 md:gap-4">
    <label for="timer-description" class="sr-only"
      >What are you working on?</label
    >
    <input
      id="timer-description"
      bind:value={$form.description}
      bind:this={descriptionInput}
      placeholder="What are you working on?"
      disabled={isRunning}
      onkeydown={handleDescriptionKeydown}
      class="flex-1 min-w-0 bg-transparent text-lg md:text-xl text-fg-primary placeholder:text-fg-muted outline-none py-2 disabled:opacity-100"
      autocomplete="off"
    />

    <div class="flex items-center gap-1 md:gap-2 flex-wrap">
      <Popover.Root bind:open={showProjectDropdown}>
        <Popover.Trigger disabled={isRunning}>
          {#snippet child({ props })}
            <button
              {...props}
              type="button"
              class="{iconButton} max-w-48"
              aria-label={selectedProject
                ? `Project: ${selectedProject.name}`
                : "Select project"}
              title={selectedProject ? selectedProject.name : "Project"}
            >
              {#if selectedProject}
                <span
                  class="w-2.5 h-2.5 rounded-full shrink-0"
                  style="background-color: {selectedProject.color}"
                  aria-hidden="true"
                ></span>
                <span
                  class="truncate text-sm font-medium"
                  style="color: {selectedProject.color}"
                  >{selectedProject.name}</span
                >
              {:else}
                <Folder class="w-5 h-5" aria-hidden="true" />
              {/if}
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
              <Command.List class="p-1">
                <Command.Empty>No matching projects.</Command.Empty>
                {#if selectedProject}
                  <Command.Item
                    value="No project"
                    onSelect={() => selectProject(null)}
                    class="gap-3 px-3 py-2 rounded-lg text-fg-muted"
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
                    class="gap-3 px-3 py-2 rounded-lg"
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
        <Popover.Trigger disabled={isRunning}>
          {#snippet child({ props })}
            <button
              {...props}
              type="button"
              class="{iconButton} {selectedTags.length > 0
                ? 'text-bright-purple'
                : ''}"
              aria-label={selectedTags.length > 0
                ? `Tags: ${selectedTags.map((t: { name: string }) => t.name).join(", ")}`
                : "Select tags"}
              title={selectedTags.length > 0
                ? selectedTags.map((t: { name: string }) => t.name).join(", ")
                : "Tags"}
            >
              <Tag class="w-5 h-5" aria-hidden="true" />
              {#if selectedTags.length > 0}
                <span class="text-sm font-medium">{selectedTags.length}</span>
              {/if}
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
              <Command.List class="p-1">
                <Command.Empty>No matching tags.</Command.Empty>
                {#each tags as tag (tag.id)}
                  <Command.Item
                    value={tag.name}
                    data-checked={$form.tag_ids.includes(tag.id)}
                    onSelect={() => toggleTag(tag.id)}
                    class="px-3 py-2 rounded-lg"
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
        disabled={isRunning}
        class="{iconButton} {$form.billable ? 'text-bright-green' : ''}"
        aria-pressed={$form.billable}
        aria-label="Billable"
        title={$form.billable ? "Billable" : "Non-billable"}
        onclick={() => ($form.billable = !$form.billable)}
      >
        <DollarSign class="w-5 h-5" aria-hidden="true" />
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
          <Paperclip class="w-5 h-5" aria-hidden="true" />
          {#if selectedFiles.length > 0}
            <span
              class="absolute -top-0.5 -right-0.5 w-4 h-4 bg-bright-blue text-bg-primary text-xs rounded-full flex items-center justify-center"
            >
              {selectedFiles.length}
            </span>
          {/if}
        </button>
      {/if}

      {#if isManual}
        <div class="flex items-center gap-1 text-sm">
          <label class="sr-only" for="manual-start">Start time</label>
          <input
            id="manual-start"
            type="time"
            bind:value={manualStart}
            class={timeField}
          />
          <span class="text-fg-dim" aria-hidden="true">–</span>
          <label class="sr-only" for="manual-end">End time</label>
          <input
            id="manual-end"
            type="time"
            bind:value={manualEnd}
            class={timeField}
          />
          <DatePicker
            id="manual-date"
            bind:value={manualDate}
            max={new Date()}
            format={(date) =>
              date.toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
              })}
            class="w-auto gap-1.5 px-2 py-1.5 border-transparent bg-transparent hover:bg-bg-tertiary hover:border-transparent data-[state=open]:border-transparent data-[state=open]:bg-bg-tertiary"
          />
        </div>
      {/if}

      <div class="flex items-center gap-3 ml-auto md:ml-2">
        <span
          class="text-xl md:text-2xl font-tabular font-semibold text-fg-primary min-w-24 text-right"
          role="timer"
          aria-live="off"
          aria-label={isRunning ? "Elapsed time" : "Duration"}
        >
          {formatDuration(displayedSeconds)}
        </span>

        {#if runningEntry}
          <button
            onclick={stopTimer}
            class="size-12 shrink-0 grid place-items-center rounded-full bg-bright-red hover:bg-accent-red text-bg-primary ring-4 ring-bright-red/20 transition-colors duration-150"
            aria-label="Stop timer"
          >
            <Square class="w-5 h-5 fill-current" aria-hidden="true" />
          </button>
        {:else if isManual}
          <button
            onclick={addManualEntry}
            disabled={!$form.description.trim() || displayedSeconds <= 0}
            class="h-12 shrink-0 px-5 rounded-full bg-bright-purple hover:bg-accent-purple text-bg-primary font-semibold ring-4 ring-bright-purple/20 transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Add
          </button>
        {:else}
          <button
            onclick={startTimer}
            disabled={!$form.description.trim()}
            class="size-12 shrink-0 grid place-items-center rounded-full bg-bright-purple hover:bg-accent-purple text-bg-primary ring-4 ring-bright-purple/20 transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
            aria-label="Start timer"
          >
            <Play class="w-5 h-5 ml-0.5 fill-current" aria-hidden="true" />
          </button>
        {/if}

        {#if !isRunning}
          <div class="flex flex-col" role="radiogroup" aria-label="Entry mode">
            <button
              type="button"
              role="radio"
              aria-checked={mode === "timer"}
              aria-label="Timer mode"
              title="Timer mode"
              onclick={() => (mode = "timer")}
              class="p-0.5 rounded-full transition-colors duration-150 {mode ===
              'timer'
                ? 'text-fg-primary'
                : 'text-fg-dim hover:text-fg-secondary'}"
            >
              <CirclePlay class="w-5 h-5" aria-hidden="true" />
            </button>
            <button
              type="button"
              role="radio"
              aria-checked={mode === "manual"}
              aria-label="Manual mode"
              title="Manual mode: add a finished entry"
              onclick={() => (mode = "manual")}
              class="p-0.5 rounded-full transition-colors duration-150 {mode ===
              'manual'
                ? 'text-fg-primary'
                : 'text-fg-dim hover:text-fg-secondary'}"
            >
              <CirclePlus class="w-5 h-5" aria-hidden="true" />
            </button>
          </div>
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
