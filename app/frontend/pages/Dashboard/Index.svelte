<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import TimerInput from '../../components/TimerInput.svelte'
  import { page } from '@inertiajs/svelte'
  import { Play, Edit2, Trash2, DollarSign } from 'lucide-svelte'

  let runningEntry = $derived($page.props.runningEntry)
  let recentEntries = $derived($page.props.recentEntries || [])
  let projects = $derived($page.props.projects || [])
  let tags = $derived($page.props.tags || [])

  function formatDate(dateString: string): string {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  }

  function formatTime(dateString: string): string {
    const date = new Date(dateString)
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
  }
</script>

<AppShell>
  <TimerInput {runningEntry} {projects} {tags} />

  <!-- Main Dashboard Content -->
  <div class="flex-1 p-6 overflow-auto">
    <div class="max-w-4xl mx-auto space-y-6">
      <!-- Page Header -->
      <div class="flex items-center justify-between">
        <h2 class="text-2xl font-semibold">Timer</h2>
      </div>

      <!-- Flash Messages -->
      {#if $page.props.flash?.notice}
        <div class="bg-bright-green/10 border border-bright-green text-bright-green px-4 py-3 rounded-[10px] animate-slide-in">
          {$page.props.flash.notice}
        </div>
      {/if}

      {#if $page.props.flash?.alert}
        <div class="bg-bright-red/10 border border-bright-red text-bright-red px-4 py-3 rounded-[10px] animate-slide-in">
          {$page.props.flash.alert}
        </div>
      {/if}

      <!-- Recent Entries -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
        <div class="p-4 border-b border-bg-tertiary">
          <h3 class="font-semibold text-lg">Recent Entries</h3>
        </div>

        {#if recentEntries.length === 0}
          <div class="p-8 text-center text-fg-muted">
            <p>No time entries yet. Start tracking your time above!</p>
          </div>
        {:else}
          <div class="divide-y divide-bg-tertiary">
            {#each recentEntries as entry}
              <div class="p-4 flex items-center gap-4 hover:bg-bg-tertiary/50 transition-colors duration-150">
                <!-- Date & Time -->
                <div class="w-24 text-sm text-fg-muted">
                  <div>{formatDate(entry.start_at)}</div>
                  <div>{formatTime(entry.start_at)} - {entry.end_at ? formatTime(entry.end_at) : 'now'}</div>
                </div>

                <!-- Description -->
                <div class="flex-1 min-w-0">
                  <p class="font-medium truncate">{entry.description || 'No description'}</p>
                  {#if entry.project}
                    <div class="flex items-center gap-2 mt-1">
                      <span 
                        class="w-3 h-3 rounded-full" 
                        style="background-color: {entry.project.color || '#b16286'}"
                      ></span>
                      <span class="text-sm text-fg-muted">{entry.project.name}</span>
                    </div>
                  {/if}
                </div>

                <!-- Billable Indicator -->
                {#if entry.billable}
                  <DollarSign class="w-4 h-4 text-bright-green" />
                {/if}

                <!-- Duration -->
                <div class="text-right min-w-[80px]">
                  <span class="font-tabular font-medium">{entry.formattedDuration}</span>
                </div>

                <!-- Actions -->
                <div class="flex items-center gap-2">
                  <button class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150" aria-label="Edit entry">
                    <Edit2 class="w-4 h-4" />
                  </button>
                  <button class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150" aria-label="Delete entry">
                    <Trash2 class="w-4 h-4" />
                  </button>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  </div>
</AppShell>
