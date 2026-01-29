<script lang="ts">
  import { Play, Square, DollarSign, Check, X, Paperclip } from "lucide-svelte";
  import { router, useForm, page, Link } from "@inertiajs/svelte";

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
    $form.post(`/${workspaceId}/time_entries`, {
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
      `/${workspaceId}/time_entries/${runningEntry.id}/stop`,
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

  function formatFileSize(bytes: number): string {
    if (bytes === 0) return "0 Bytes";
    const k = 1024;
    const sizes = ["Bytes", "KB", "MB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
  }

  function selectProject(project: { id: number; billable_default: boolean }) {
    $form.project_id = project.id;
    if (project.billable_default) {
      $form.billable = true;
    }
    showProjectDropdown = false;
  }

  function toggleTag(tagId: number) {
    const index = $form.tag_ids.indexOf(tagId);
    if (index === -1) {
      $form.tag_ids = [...$form.tag_ids, tagId];
    } else {
      $form.tag_ids = $form.tag_ids.filter((id: number) => id !== tagId);
    }
  }

  function clearProject() {
    $form.project_id = null;
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === "Escape") {
      showProjectDropdown = false;
      showTagDropdown = false;
    }
  }

  function handleDescriptionKeydown(event: KeyboardEvent) {
    if (event.key === "Enter" && !isRunning && $form.description.trim()) {
      event.preventDefault();
      startTimer();
    }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

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
      <input
        id="timer-description"
        type="text"
        placeholder="What are you working on?"
        bind:value={$form.description}
        bind:this={descriptionInput}
        disabled={isRunning}
        onkeydown={handleDescriptionKeydown}
        class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-3 md:px-4 py-2.5 md:py-3 text-fg-primary placeholder:text-fg-dim focus:border-bright-blue transition-colors duration-150 disabled:opacity-50 text-sm md:text-base"
        aria-label="Task description"
        autocomplete="off"
      />
    </div>

    <div class="flex items-center gap-2 md:gap-4 flex-wrap md:flex-nowrap">
      <div class="relative">
        {#if selectedProject}
          <div class="flex items-center gap-1">
            <button
              disabled={isRunning}
              onclick={() =>
                !isRunning && (showProjectDropdown = !showProjectDropdown)}
              class="flex items-center gap-1.5 md:gap-2 px-3 md:px-4 py-2 md:py-3 bg-bg-primary border border-bg-tertiary rounded-[10px] hover:border-bright-blue transition-colors duration-150 disabled:opacity-50 text-sm md:text-base"
              aria-haspopup="listbox"
              aria-expanded={showProjectDropdown}
              aria-label="Selected project: {selectedProject.name}"
            >
              <span
                class="w-3 h-3 rounded-full"
                style="background-color: {selectedProject.color}"
                aria-hidden="true"
              ></span>
              <span class="text-fg-primary">{selectedProject.name}</span>
            </button>
            {#if !isRunning}
              <button
                type="button"
                onclick={clearProject}
                class="p-2 text-fg-muted hover:text-bright-red rounded-[10px] hover:bg-bg-secondary transition-colors duration-150"
                aria-label="Clear project selection"
              >
                <X class="w-4 h-4" aria-hidden="true" />
              </button>
            {/if}
          </div>
        {:else}
          <button
            disabled={isRunning}
            onclick={() => (showProjectDropdown = !showProjectDropdown)}
            class="px-3 md:px-4 py-2 md:py-3 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-muted hover:text-fg-primary transition-colors duration-150 disabled:opacity-50 text-sm md:text-base"
            aria-haspopup="listbox"
            aria-expanded={showProjectDropdown}
            aria-label="Select project"
          >
            Project
          </button>
        {/if}

        {#if showProjectDropdown && !isRunning}
          <div
            class="absolute top-full left-0 mt-2 w-64 bg-bg-secondary border border-bg-tertiary rounded-[10px] shadow-lg z-50 animate-slide-in"
            role="listbox"
            aria-label="Available projects"
          >
            <div class="p-2 max-h-64 overflow-y-auto">
              {#if projects.length === 0}
                <p class="p-3 text-fg-muted text-sm">
                  No projects yet. <Link
                    href="/{workspaceId}/projects"
                    class="text-bright-blue hover:underline">Create one</Link
                  >.
                </p>
              {:else}
                {#each projects as project}
                  <button
                    onclick={() => selectProject(project)}
                    class="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-bg-tertiary transition-colors duration-150 text-left"
                    role="option"
                    aria-selected={$form.project_id === project.id}
                  >
                    <span
                      class="w-3 h-3 rounded-full"
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
                    {#if $form.project_id === project.id}
                      <Check
                        class="w-4 h-4 text-bright-green"
                        aria-hidden="true"
                      />
                    {/if}
                  </button>
                {/each}
              {/if}
            </div>
          </div>
        {/if}
      </div>

      <div class="relative">
        <button
          disabled={isRunning}
          onclick={() => (showTagDropdown = !showTagDropdown)}
          class="flex items-center gap-1.5 md:gap-2 px-3 md:px-4 py-2 md:py-3 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-muted hover:text-fg-primary transition-colors duration-150 disabled:opacity-50 text-sm md:text-base"
          aria-haspopup="listbox"
          aria-expanded={showTagDropdown}
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
        </button>

        {#if showTagDropdown && !isRunning}
          <div
            class="absolute top-full left-0 mt-2 w-56 bg-bg-secondary border border-bg-tertiary rounded-[10px] shadow-lg z-50 animate-slide-in"
            role="listbox"
            aria-label="Available tags"
            aria-multiselectable="true"
          >
            <div class="p-2 max-h-64 overflow-y-auto">
              {#if tags.length === 0}
                <p class="p-3 text-fg-muted text-sm">
                  No tags yet. <Link
                    href="/{workspaceId}/tags"
                    class="text-bright-blue hover:underline">Create one</Link
                  >.
                </p>
              {:else}
                {#each tags as tag}
                  <button
                    onclick={() => toggleTag(tag.id)}
                    class="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-bg-tertiary transition-colors duration-150 text-left"
                    role="option"
                    aria-selected={$form.tag_ids.includes(tag.id)}
                  >
                    <span class="text-fg-primary">{tag.name}</span>
                    {#if $form.tag_ids.includes(tag.id)}
                      <Check
                        class="w-4 h-4 text-bright-green ml-auto"
                        aria-hidden="true"
                      />
                    {/if}
                  </button>
                {/each}
              {/if}
            </div>
          </div>
        {/if}
      </div>

      <button
        type="button"
        onclick={() => ($form.billable = !$form.billable)}
        disabled={isRunning}
        class="flex items-center gap-1.5 md:gap-2 px-3 md:px-4 py-2 md:py-3 bg-bg-primary border rounded-[10px] transition-colors duration-150 disabled:opacity-50 text-sm md:text-base {$form.billable
          ? 'border-bright-green text-bright-green'
          : 'border-bg-tertiary text-fg-muted hover:text-fg-primary'}"
        aria-pressed={$form.billable}
      >
        <DollarSign class="w-4 h-4" aria-hidden="true" />
        <span>Billable</span>
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

{#if showProjectDropdown || showTagDropdown}
  <button
    type="button"
    class="fixed inset-0 z-40 bg-transparent"
    onclick={() => {
      showProjectDropdown = false;
      showTagDropdown = false;
    }}
    aria-label="Close dropdowns"
  ></button>
{/if}
