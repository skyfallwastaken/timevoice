<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import { page } from '@inertiajs/svelte'
  import { List, Clock, Search } from 'lucide-svelte'

  let entries = $derived($page.props.entries || [])
  let filters = $state({
    search: '',
    project: '',
    dateRange: 'this_week'
  })
</script>

<AppShell>
  <div class="flex-1 p-6 overflow-auto">
    <div class="max-w-6xl mx-auto space-y-6">
      <!-- Page Header -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <List class="w-6 h-6 text-bright-blue" />
          <h2 class="text-2xl font-semibold">Time Entries</h2>
        </div>
      </div>

      <!-- Filters -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
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
            bind:value={filters.project}
            class="bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
          >
            <option value="">All Projects</option>
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

      <!-- Entries List -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
        <div class="p-4 border-b border-bg-tertiary">
          <h3 class="font-semibold">Entries</h3>
        </div>
        <div class="p-8 text-center text-fg-muted">
          <List class="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>Time entries list coming soon</p>
        </div>
      </div>
    </div>
  </div>
</AppShell>
