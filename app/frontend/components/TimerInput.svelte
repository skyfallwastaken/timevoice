<script lang="ts">
  import { Play, Square, DollarSign, Check, X } from 'lucide-svelte'
  import { router, useForm } from '@inertiajs/svelte'

  let { runningEntry, projects = [], tags = [] } = $props()

  let form = useForm({
    description: '',
    project_id: null as number | null,
    tag_ids: [] as number[],
    billable: false,
    start_at: new Date().toISOString()
  })

  let showProjectDropdown = $state(false)
  let showTagDropdown = $state(false)
  let elapsed = $state(0)
  let timerInterval: ReturnType<typeof setInterval> | null = null
  let descriptionInput: HTMLInputElement | null = $state(null)

  let selectedProject = $derived(
    projects.find((p: { id: number }) => p.id === $form.project_id)
  )

  let selectedTags = $derived(
    tags.filter((t: { id: number }) => $form.tag_ids.includes(t.id))
  )

  let isRunning = $derived(!!runningEntry)

  $effect(() => {
    if (runningEntry) {
      const startTime = new Date(runningEntry.start_at).getTime()
      elapsed = Math.floor((Date.now() - startTime) / 1000)
      
      timerInterval = setInterval(() => {
        elapsed = Math.floor((Date.now() - startTime) / 1000)
      }, 1000)
    } else {
      elapsed = 0
      if (timerInterval) {
        clearInterval(timerInterval)
        timerInterval = null
      }
    }
    
    return () => {
      if (timerInterval) {
        clearInterval(timerInterval)
      }
    }
  })

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`
  }

  function startTimer() {
    if (!$form.description.trim()) return
    
    $form.start_at = new Date().toISOString()
    $form.post('/time_entries', {
      preserveScroll: true,
      onSuccess: () => {
        $form.reset()
        showProjectDropdown = false
        showTagDropdown = false
      }
    })
  }

  function stopTimer() {
    if (!runningEntry) return

    router.patch(`/time_entries/${runningEntry.id}/stop`, {}, {
      preserveScroll: true,
      onSuccess: () => {
        // Focus back on description after stopping
        setTimeout(() => descriptionInput?.focus(), 100)
      }
    })
  }

  function selectProject(project: { id: number; billable_default: boolean }) {
    $form.project_id = project.id
    if (project.billable_default) {
      $form.billable = true
    }
    showProjectDropdown = false
  }

  function toggleTag(tagId: number) {
    const index = $form.tag_ids.indexOf(tagId)
    if (index === -1) {
      $form.tag_ids = [...$form.tag_ids, tagId]
    } else {
      $form.tag_ids = $form.tag_ids.filter((id: number) => id !== tagId)
    }
  }

  function clearProject() {
    $form.project_id = null
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      showProjectDropdown = false
      showTagDropdown = false
    }
  }

  function handleDescriptionKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !isRunning && $form.description.trim()) {
      event.preventDefault()
      startTimer()
    }
  }
</script>

<svelte:window on:keydown={handleKeydown} />

<div class="bg-bg-secondary border-b border-bg-tertiary p-4" role="region" aria-label="Time tracker">
  <div class="flex items-center gap-4">
    <!-- Description Input -->
    <div class="flex-1">
      <label for="timer-description" class="sr-only">What are you working on?</label>
      <input
        id="timer-description"
        type="text"
        placeholder="What are you working on?"
        bind:value={$form.description}
         bind:this={descriptionInput}
         disabled={isRunning}
         onkeydown={handleDescriptionKeydown}
         class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-3 text-fg-primary placeholder:text-fg-dim focus:border-bright-blue transition-colors duration-150 disabled:opacity-50"
        aria-label="Task description"
        autocomplete="off"
      />
    </div>

    <!-- Project Selector -->
    <div class="relative">
      {#if selectedProject}
        <div class="flex items-center gap-1">
          <button 
            disabled={isRunning}
            onclick={() => !isRunning && (showProjectDropdown = !showProjectDropdown)}
            class="flex items-center gap-2 px-4 py-3 bg-bg-primary border border-bg-tertiary rounded-[10px] hover:border-bright-blue transition-colors duration-150 disabled:opacity-50"
            aria-haspopup="listbox"
            aria-expanded={showProjectDropdown}
            aria-label="Selected project: {selectedProject.name}"
          >
            <span class="w-3 h-3 rounded-full" style="background-color: {selectedProject.color}" aria-hidden="true"></span>
            <span class="text-fg-primary">{selectedProject.name}</span>
          </button>
          {#if !isRunning}
            <button 
              type="button"
              onclick={() => clearProject()} 
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
          onclick={() => showProjectDropdown = !showProjectDropdown}
          class="px-4 py-3 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-muted hover:text-fg-primary transition-colors duration-150 disabled:opacity-50"
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
              <p class="p-3 text-fg-muted text-sm">No projects yet. <a href="/projects" class="text-bright-blue hover:underline">Create one</a>.</p>
            {:else}
              {#each projects as project}
                <button
                  onclick={() => selectProject(project)}
                  class="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] hover:bg-bg-tertiary transition-colors duration-150 text-left"
                  role="option"
                  aria-selected={$form.project_id === project.id}
                >
                  <span class="w-3 h-3 rounded-full" style="background-color: {project.color}" aria-hidden="true"></span>
                  <div class="flex-1 min-w-0">
                    <p class="text-fg-primary truncate">{project.name}</p>
                    {#if project.client}
                      <p class="text-xs text-fg-muted truncate">{project.client.name}</p>
                    {/if}
                  </div>
                  {#if $form.project_id === project.id}
                    <Check class="w-4 h-4 text-bright-green" aria-hidden="true" />
                  {/if}
                </button>
              {/each}
            {/if}
          </div>
        </div>
      {/if}
    </div>

    <!-- Tags Selector -->
    <div class="relative">
      <button 
        disabled={isRunning}
        onclick={() => showTagDropdown = !showTagDropdown}
        class="flex items-center gap-2 px-4 py-3 bg-bg-primary border border-bg-tertiary rounded-[10px] text-fg-muted hover:text-fg-primary transition-colors duration-150 disabled:opacity-50"
        aria-haspopup="listbox"
        aria-expanded={showTagDropdown}
        aria-label={selectedTags.length > 0 ? `Selected ${selectedTags.length} tags` : 'Select tags'}
      >
        {#if selectedTags.length > 0}
          <span class="text-fg-primary">{selectedTags.length} tag{selectedTags.length === 1 ? '' : 's'}</span>
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
              <p class="p-3 text-fg-muted text-sm">No tags yet. <a href="/tags" class="text-bright-blue hover:underline">Create one</a>.</p>
            {:else}
              {#each tags as tag}
                <button
                  onclick={() => toggleTag(tag.id)}
                  class="w-full flex items-center gap-3 px-3 py-2 rounded-[8px] hover:bg-bg-tertiary transition-colors duration-150 text-left"
                  role="option"
                  aria-selected={$form.tag_ids.includes(tag.id)}
                >
                  <span class="text-fg-primary">{tag.name}</span>
                  {#if $form.tag_ids.includes(tag.id)}
                    <Check class="w-4 h-4 text-bright-green ml-auto" aria-hidden="true" />
                  {/if}
                </button>
              {/each}
            {/if}
          </div>
        </div>
      {/if}
    </div>

    <!-- Billable Toggle -->
    <button
      type="button"
      onclick={() => $form.billable = !$form.billable}
      disabled={isRunning}
      class="flex items-center gap-2 px-4 py-3 bg-bg-primary border rounded-[10px] transition-colors duration-150 disabled:opacity-50 {$form.billable ? 'border-bright-green text-bright-green' : 'border-bg-tertiary text-fg-muted hover:text-fg-primary'}"
      aria-pressed={$form.billable}
    >
      <DollarSign class="w-4 h-4" aria-hidden="true" />
      <span>Billable</span>
    </button>

    <!-- Timer Display & Controls -->
    <div class="flex items-center gap-3" role="timer" aria-label={isRunning ? 'Timer running' : 'Timer stopped'}>
      <span class="text-3xl font-tabular font-semibold text-fg-primary min-w-[100px] text-center" aria-live="polite" aria-atomic="true">
        {formatDuration(elapsed)}
      </span>
      
      {#if runningEntry}
        <button
          onclick={stopTimer}
          class="p-4 bg-bright-red hover:bg-accent-red text-bg-primary rounded-[10px] transition-colors duration-150"
          aria-label="Stop timer"
        >
          <Square class="w-6 h-6 fill-current" aria-hidden="true" />
        </button>
      {:else}
        <button
          onclick={startTimer}
          disabled={!$form.description.trim()}
          class="p-4 bg-bright-green hover:bg-accent-green text-bg-primary rounded-[10px] transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          aria-label="Start timer"
        >
          <Play class="w-6 h-6 fill-current" aria-hidden="true" />
        </button>
      {/if}
    </div>
  </div>
</div>

<!-- Click outside to close dropdowns -->
{#if showProjectDropdown || showTagDropdown}
  <button 
    type="button"
    class="fixed inset-0 z-40 bg-transparent" 
    onclick={() => { showProjectDropdown = false; showTagDropdown = false; }}
    aria-label="Close dropdowns"
  ></button>
{/if}
