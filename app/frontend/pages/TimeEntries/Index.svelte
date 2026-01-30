<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import PageLayout from '../../components/PageLayout.svelte'
  import { page } from '@inertiajs/svelte'
  import { List, Search, Filter, ChevronDown, ChevronUp, DollarSign } from 'lucide-svelte'

  type Entry = {
    id: number
    description: string | null
    start_at: string
    end_at: string
    duration_seconds: number
    billable: boolean
    formattedDuration: string
    project: { id: number; name: string; color: string } | null
    tags: Array<{ id: number; name: string }>
  }

  let entries = $derived($page.props.entries as Entry[] || [])
  let showFilters = $state(false)
  let filters = $state({
    search: '',
    projectId: '',
    dateRange: 'this_week'
  })

  function formatDate(dateString: string): string {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  }

  function formatTime(dateString: string): string {
    const date = new Date(dateString)
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
  }

  function getProjectOptions(allEntries: Entry[]) {
    const map = new Map<number, { id: number; name: string; color: string }>()
    for (const entry of allEntries) {
      if (!entry.project) continue
      map.set(entry.project.id, entry.project)
    }
    return Array.from(map.values()).sort((a, b) => a.name.localeCompare(b.name))
  }

  function getDateRange(range: string): { start: Date | null; end: Date | null } {
    const now = new Date()

    const startOfDay = (d: Date) => {
      const x = new Date(d)
      x.setHours(0, 0, 0, 0)
      return x
    }

    const endOfDay = (d: Date) => {
      const x = new Date(d)
      x.setHours(23, 59, 59, 999)
      return x
    }

    switch (range) {
      case 'today':
        return { start: startOfDay(now), end: endOfDay(now) }
      case 'this_week': {
        const day = now.getDay() // 0 = Sun
        const diff = (day + 6) % 7 // Monday = 0
        const start = new Date(now)
        start.setDate(now.getDate() - diff)
        const end = new Date(start)
        end.setDate(start.getDate() + 6)
        return { start: startOfDay(start), end: endOfDay(end) }
      }
      case 'last_week': {
        const day = now.getDay()
        const diff = (day + 6) % 7
        const startThisWeek = new Date(now)
        startThisWeek.setDate(now.getDate() - diff)
        const start = new Date(startThisWeek)
        start.setDate(startThisWeek.getDate() - 7)
        const end = new Date(start)
        end.setDate(start.getDate() + 6)
        return { start: startOfDay(start), end: endOfDay(end) }
      }
      case 'this_month': {
        const start = new Date(now.getFullYear(), now.getMonth(), 1)
        const end = new Date(now.getFullYear(), now.getMonth() + 1, 0)
        return { start: startOfDay(start), end: endOfDay(end) }
      }
      default:
        return { start: null, end: null }
    }
  }

  function getFilteredEntries(allEntries: Entry[]) {
    const search = filters.search.trim().toLowerCase()
    const projectId = filters.projectId
    const { start, end } = getDateRange(filters.dateRange)

    return allEntries.filter((entry) => {
      if (search) {
        const hay = (entry.description || '').toLowerCase()
        if (!hay.includes(search)) return false
      }

      if (projectId) {
        if (!entry.project || entry.project.id.toString() !== projectId) return false
      }

      if (start && end) {
        const startedAt = new Date(entry.start_at)
        if (startedAt < start || startedAt > end) return false
      }

      return true
    })
  }

  let projectOptions = $derived(getProjectOptions(entries))
  let filteredEntries = $derived(getFilteredEntries(entries))
</script>

<AppShell>
  <PageLayout title="Time Entries" icon={List} iconColor="text-bright-blue" variant="wide" flash={$page.props.flash}>
    {#snippet headerActions()}
      <button
        onclick={() => showFilters = !showFilters}
        class="flex items-center gap-2 px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
      >
        <Filter class="w-4 h-4" />
        Filters
        {#if showFilters}
          <ChevronUp class="w-4 h-4" />
        {:else}
          <ChevronDown class="w-4 h-4" />
        {/if}
      </button>
    {/snippet}

    <!-- Filters -->
    {#if showFilters}
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4 animate-slide-in">
        <div class="flex items-center gap-4">
          <div class="flex-1 relative">
            <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-fg-muted" />
            <input
              type="text"
              placeholder="Search entries..."
              bind:value={filters.search}
              class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] pl-10 pr-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue transition-colors duration-150"
            />
          </div>
          <select
            bind:value={filters.projectId}
            class="bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
          >
            <option value="">All Projects</option>
            {#each projectOptions as project}
              <option value={project.id}>{project.name}</option>
            {/each}
          </select>
          <select
            bind:value={filters.dateRange}
            class="bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
          >
            <option value="today">Today</option>
            <option value="this_week">This Week</option>
            <option value="last_week">Last Week</option>
            <option value="this_month">This Month</option>
          </select>
        </div>
      </div>
    {/if}

    <!-- Entries List -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">Entries</h3>
      </div>

      {#if filteredEntries.length === 0}
        <div class="p-8 text-center text-fg-muted">
          <List class="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No entries match your filters.</p>
        </div>
      {:else}
        <div class="divide-y divide-bg-tertiary">
          {#each filteredEntries as entry}
            <div class="p-4 flex items-center gap-4 hover:bg-bg-tertiary/50 transition-colors duration-150">
              <div class="w-32 text-sm text-fg-muted">
                <div>{formatDate(entry.start_at)}</div>
                <div>{formatTime(entry.start_at)} - {entry.end_at ? formatTime(entry.end_at) : 'now'}</div>
              </div>

              <div class="flex-1 min-w-0">
                <p class="font-medium truncate">{entry.description || 'No description'}</p>
                <div class="flex items-center gap-3 mt-1 text-sm text-fg-muted">
                  {#if entry.project}
                    <span class="flex items-center gap-2">
                      <span class="w-3 h-3 rounded-full" style="background-color: {entry.project.color}"></span>
                      <span>{entry.project.name}</span>
                    </span>
                  {/if}

                  {#if entry.tags?.length}
                    <span class="flex items-center gap-1">
                      {#each entry.tags as tag}
                        <span class="px-1.5 py-0.5 bg-bg-tertiary rounded text-xs">{tag.name}</span>
                      {/each}
                    </span>
                  {/if}
                </div>
              </div>

              {#if entry.billable}
                <DollarSign class="w-4 h-4 text-bright-green" />
              {/if}

              <div class="text-right min-w-[80px]">
                <span class="font-tabular font-medium">{entry.formattedDuration}</span>
              </div>
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </PageLayout>
</AppShell>
