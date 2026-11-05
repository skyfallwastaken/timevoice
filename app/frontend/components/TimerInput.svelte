<script lang="ts">
  import { Play, Square, DollarSign, X, Paperclip } from "lucide-svelte";
  import { router, useForm, page, Link } from "@inertiajs/svelte";
  import TextInput from "./TextInput.svelte";
  import IconButton from "./IconButton.svelte";
  import Button from "./Button.svelte";
  import ChipButton from "./ChipButton.svelte";
  import { formatFileSize } from "../lib/format";
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

  let showProjectDropdown = $state(false);
  let showTagDropdown = $state(false);
  let elapsed = $state(0);
  let timerInterval: ReturnType<typeof setInterval> | null = null;
  let descriptionInput: HTMLInputElement | null = $state(null);
  let selectedFiles: File[] = $state([]);
  let fileInput: HTMLInputElement | null = $state(null);

  let selectedProject = $derived(
    projects.find((p: { id: number }) => p.id === $form.project_id),
  );

  let selectedTags = $derived(
    tags.filter((t: { id: number }) => $form.tag_ids.includes(t.id)),
  );

  let isRunning = $derived(!!runningEntry);

  $effect(() => {
    if (runningEntry) {
      const startTime = new Date(runningEntry.start_at).getTime();
      elapsed = Math.floor((Date.now() - startTime) / 1000);

      timerInterval = setInterval(() => {
        elapsed = Math.floor((Date.now() - startTime) / 1000);
      }, 1000);
    } else {
      elapsed = 0;
      if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
      }
    }

    return () => {
      if (timerInterval) {
        clearInterval(timerInterval);
      }
    };
  });

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
    }
    return `${minutes}:${secs.toString().padStart(2, "0")}`;
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
          $form.description = "";
          $form.project_id = null;
          $form.tag_ids = [];
          $form.billable = false;
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

  function selectProject(project: { id: number; billable_default: boolean }) {
    $form.project_id = project.id;
    if (project.billable_default) $form.billable = true;
    showProjectDropdown = false;
  }

  function toggleTag(tagId: number) {
    $form.tag_ids = toggleSelectedTag($form.tag_ids, tagId);
  }

  function clearProject() {
    $form.project_id = null;
  }

  function handleDescriptionKeydown(event: KeyboardEvent) {
    if (event.key === "Enter" && !isRunning && $form.description.trim()) {
      event.preventDefault();
      startTimer();
    }
  }
</script>

<div
  class="bg-bg-secondary border-b border-bg-tertiary p-3 md:p-4"
  role="region"
  aria-label="Time tracker"
>
  <div class="flex flex-col md:flex-row gap-3 md:gap-4">
    <div class="flex-1 w-full">
      <label for="timer-description" class="sr-only"
        >What are you working on?</label
      >
      <TextInput
        id="timer-description"
        bind:value={$form.description}
        bind:inputRef={descriptionInput}
        placeholder="What are you working on?"
        disabled={isRunning}
        onkeydown={handleDescriptionKeydown}
        class="px-3 md:px-4 py-2.5 md:py-3 text-sm md:text-base"
        aria-label="Task description"
        autocomplete="off"
      />
    </div>

    <div class="flex items-center gap-2 md:gap-4 flex-wrap md:flex-nowrap">
      <div class="flex items-center gap-1">
        <Popover.Root bind:open={showProjectDropdown}>
          <Popover.Trigger disabled={isRunning}>
            {#snippet child({ props })}
              <Button
                {...props}
                variant="secondary"
                class="bg-bg-primary border-bg-tertiary {selectedProject
                  ? 'hover:border-bright-blue'
                  : ''} px-3 md:px-4 py-2 md:py-3 text-sm md:text-base"
                aria-label={selectedProject
                  ? `Selected project: ${selectedProject.name}`
                  : "Select project"}
              >
                {#if selectedProject}
                  <span
                    class="w-3 h-3 rounded-full"
                    style="background-color: {selectedProject.color}"
                    aria-hidden="true"
                  ></span>
                  <span class="text-fg-primary">{selectedProject.name}</span>
                {:else}
                  Project
                {/if}
              </Button>
            {/snippet}
          </Popover.Trigger>
          <Popover.Content align="start" class="w-64 p-0">
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
        {#if selectedProject && !isRunning}
          <IconButton
            type="button"
            tone="danger"
            onclick={clearProject}
            class="hover:bg-bg-secondary"
            aria-label="Clear project selection"
          >
            <X class="w-4 h-4" aria-hidden="true" />
          </IconButton>
        {/if}
      </div>

      <Popover.Root bind:open={showTagDropdown}>
        <Popover.Trigger disabled={isRunning}>
          {#snippet child({ props })}
            <Button
              {...props}
              variant="secondary"
              class="bg-bg-primary border-bg-tertiary px-3 md:px-4 py-2 md:py-3 text-sm md:text-base"
              aria-label={selectedTags.length > 0
                ? `Selected ${selectedTags.length} tags`
                : "Select tags"}
            >
              {#if selectedTags.length > 0}
                <span class="text-fg-primary"
                  >{selectedTags.length} tag{selectedTags.length === 1
                    ? ""
                    : "s"}</span
                >
              {:else}
                Tags
              {/if}
            </Button>
          {/snippet}
        </Popover.Trigger>
        <Popover.Content align="start" class="w-56 p-0">
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
      <ChipButton
        type="button"
        selected={$form.billable}
        disabled={isRunning}
        class={$form.billable
          ? "border-bright-green text-bright-green"
          : "border-bg-tertiary text-fg-muted hover:text-fg-primary"}
        aria-pressed={$form.billable}
        onclick={() => ($form.billable = !$form.billable)}
      >
        <DollarSign class="w-4 h-4" aria-hidden="true" />
        <span>Billable</span>
      </ChipButton>

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
          class="relative p-2 md:p-3 text-fg-muted hover:text-fg-primary border border-bg-tertiary rounded-[10px] hover:border-bright-blue transition-colors duration-150 disabled:opacity-50"
          aria-label="Attach files"
        >
          <Paperclip class="w-5 h-5" />
          {#if selectedFiles.length > 0}
            <span
              class="absolute -top-1 -right-1 w-4 h-4 bg-bright-blue text-bg-primary text-xs rounded-full flex items-center justify-center"
            >
              {selectedFiles.length}
            </span>
          {/if}
        </button>
      {/if}

      <div
        class="flex items-center gap-2 md:gap-3 ml-auto md:ml-0"
        role="timer"
        aria-label={isRunning ? "Timer running" : "Timer stopped"}
      >
        <span
          class="text-2xl md:text-3xl font-tabular font-semibold text-fg-primary min-w-20 md:min-w-25 text-center"
          aria-live="polite"
          aria-atomic="true"
        >
          {formatDuration(elapsed)}
        </span>

        {#if runningEntry}
          <button
            onclick={stopTimer}
            class="p-3 md:p-4 bg-bright-red hover:bg-accent-red text-bg-primary rounded-[10px] transition-colors duration-150"
            aria-label="Stop timer"
          >
            <Square
              class="w-5 h-5 md:w-6 md:h-6 fill-current"
              aria-hidden="true"
            />
          </button>
        {:else}
          <button
            onclick={startTimer}
            disabled={!$form.description.trim()}
            class="p-3 md:p-4 bg-bright-green hover:bg-accent-green text-bg-primary rounded-[10px] transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
            aria-label="Start timer"
          >
            <Play
              class="w-5 h-5 md:w-6 md:h-6 fill-current"
              aria-hidden="true"
            />
          </button>
        {/if}
      </div>
    </div>

    {#if runningEntry && selectedFiles.length > 0}
      <div class="border-t border-bg-tertiary pt-3">
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
</div>
