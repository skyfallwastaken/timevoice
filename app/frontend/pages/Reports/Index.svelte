<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { page } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { DateInput } from "date-picker-svelte";
  import {
    BarChart3,
    Calendar,
    DollarSign,
    Clock,
    Filter,
    ChevronDown,
    ChevronUp,
  } from "lucide-svelte";
  import { formatShortDate } from "../../lib/format";
  import type { TimeEntry, Project } from "../../types";

  type ProjectBreakdown = {
    total: number;
    billable: number;
  };

  type ClientBreakdown = {
    total: number;
    billable: number;
  };

  type DayBreakdown = {
    total: number;
    billable: number;
  };

  type Totals = {
    total: number;
    billable: number;
    non_billable: number;
    daily: Record<string, DayBreakdown>;
    by_project: Record<string, ProjectBreakdown>;
    by_client: Record<string, ClientBreakdown>;
  };

  let entries = $derived(($page.props.entries as TimeEntry[]) || []);
  let totals = $derived(
    ($page.props.totals as Totals) || {
      total: 0,
      billable: 0,
      non_billable: 0,
      daily: {},
      by_project: {},
      by_client: {},
    },
  );

  let projects = $derived(($page.props.projects as Project[]) || []);

  let showFilters = $state(false);
  let selectedProjectId = $state("");

  const initialDateRange = ($page.props.dateRange as {
    start: string;
    end: string;
  }) || { start: "", end: "" };

  let dateFilterForm = useForm({
    start_date: initialDateRange.start,
    end_date: initialDateRange.end,
  });

  let startDate = $state<Date | null>(
    initialDateRange.start
      ? new Date(initialDateRange.start + "T00:00:00")
      : null,
  );
  let endDate = $state<Date | null>(
    initialDateRange.end ? new Date(initialDateRange.end + "T00:00:00") : null,
  );

  function formatISODate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function updateDateRange() {
    if (startDate && endDate && startDate <= endDate) {
      $dateFilterForm.start_date = formatISODate(startDate);
      $dateFilterForm.end_date = formatISODate(endDate);
      const auth = $page.props.auth as { workspace: { hashid: string } };
      $dateFilterForm.get(`/${auth.workspace.hashid}/reports`);
    }
  }

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }



  function formatDayOfWeek(dateStr: string): string {
    return new Date(`${dateStr}T00:00:00`).toLocaleDateString("en-US", {
      weekday: "short",
    });
  }

  let filteredEntries = $derived(
    selectedProjectId
      ? entries.filter((e) => e.project?.id.toString() === selectedProjectId)
      : entries,
  );

  let canUpdateRange = $derived(
    !!startDate &&
      !!endDate &&
      startDate <= endDate &&
      !$dateFilterForm.processing,
  );
</script>

<PageLayout
  title="Reports"
  icon={BarChart3}
  iconColor="text-bright-purple"
  variant="wide"
  flash={$page.props.flash}
>
  {#snippet headerActions()}
    <button
      onclick={() => (showFilters = !showFilters)}
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

  {#if showFilters}
    <div
      class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4 animate-slide-in"
    >
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
        <div>
          <label
            for="report-start"
            class="block text-sm font-medium text-fg-secondary mb-1"
            >Start Date</label
          >
          <div class="date-input-gruvbox">
            <DateInput
              id="report-start"
              bind:value={startDate}
              max={endDate || undefined}
              placeholder="Select start date"
              format="yyyy-MM-dd"
              closeOnSelection={true}
            />
          </div>
        </div>
        <div>
          <label
            for="report-end"
            class="block text-sm font-medium text-fg-secondary mb-1"
            >End Date</label
          >
          <div class="date-input-gruvbox">
            <DateInput
              id="report-end"
              bind:value={endDate}
              min={startDate || undefined}
              placeholder="Select end date"
              format="yyyy-MM-dd"
              closeOnSelection={true}
            />
          </div>
        </div>
        <button
          onclick={updateDateRange}
          disabled={!canUpdateRange}
          class="flex items-center justify-center gap-2 px-4 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] font-medium transition-colors duration-150 disabled:opacity-50"
        >
          <Calendar class="w-4 h-4" />
          Update Range
        </button>
      </div>
      <div class="mt-4 pt-4 border-t border-bg-tertiary">
        <label
          for="report-project"
          class="block text-sm font-medium text-fg-secondary mb-1"
          >Filter by Project</label
        >
        <select
          id="report-project"
          bind:value={selectedProjectId}
          class="w-full md:w-1/2 bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-purple transition-colors duration-150"
        >
          <option value="">All Projects</option>
          {#each projects as project}
            <option value={project.id}>{project.name}</option>
          {/each}
        </select>
      </div>
    </div>
  {/if}

  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
      <div class="flex items-center gap-2 text-fg-muted mb-2">
        <Clock class="w-4 h-4" />
        <span class="text-sm">Total Hours</span>
      </div>
      <p class="text-2xl font-semibold">{formatDuration(totals.total)}</p>
    </div>

    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
      <div class="flex items-center gap-2 text-bright-green mb-2">
        <DollarSign class="w-4 h-4" />
        <span class="text-sm">Billable Hours</span>
      </div>
      <p class="text-2xl font-semibold text-bright-green">
        {formatDuration(totals.billable)}
      </p>
    </div>

    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
      <div class="flex items-center gap-2 text-fg-muted mb-2">
        <Clock class="w-4 h-4" />
        <span class="text-sm">Non-Billable Hours</span>
      </div>
      <p class="text-2xl font-semibold">
        {formatDuration(totals.non_billable)}
      </p>
    </div>
  </div>

  {#if Object.keys(totals.daily).length > 0}
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">Daily Breakdown</h3>
      </div>
      <div class="divide-y divide-bg-tertiary">
        {#each Object.entries(totals.daily) as [date, data]}
          <div class="p-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="text-center min-w-12">
                <span class="block text-xs text-fg-muted"
                  >{formatDayOfWeek(date)}</span
                >
                <span class="block text-lg font-semibold"
                  >{new Date(date).getDate()}</span
                >
              </div>
              <span class="text-fg-muted">{formatShortDate(date)}</span>
            </div>
            <div class="flex items-center gap-4">
              <div class="text-right">
                <span class="text-bright-green"
                  >{formatDuration(data.billable)} billable</span
                >
              </div>
              <span class="font-semibold">{formatDuration(data.total)}</span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  {#if Object.keys(totals.by_project).length > 0}
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">Breakdown by Project</h3>
      </div>
      <div class="divide-y divide-bg-tertiary">
        {#each Object.entries(totals.by_project) as [projectName, data]}
          <div class="p-4 flex items-center justify-between">
            <span class="font-medium">{projectName}</span>
            <div class="flex items-center gap-4">
              <span class="text-bright-green"
                >{formatDuration(data.billable)} billable</span
              >
              <span class="font-semibold">{formatDuration(data.total)}</span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  {#if Object.keys(totals.by_client).length > 0}
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">Breakdown by Client</h3>
      </div>
      <div class="divide-y divide-bg-tertiary">
        {#each Object.entries(totals.by_client) as [clientName, data]}
          <div class="p-4 flex items-center justify-between">
            <span class="font-medium">{clientName}</span>
            <div class="flex items-center gap-4">
              <span class="text-bright-green"
                >{formatDuration(data.billable)} billable</span
              >
              <span class="font-semibold">{formatDuration(data.total)}</span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
    <div class="p-4 border-b border-bg-tertiary">
      <h3 class="font-semibold">Time Entries ({filteredEntries.length})</h3>
    </div>

    {#if filteredEntries.length === 0}
      <div class="p-8 text-center text-fg-muted">
        <Clock class="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>No time entries for the selected period.</p>
      </div>
    {:else}
      <div class="divide-y divide-bg-tertiary max-h-150 overflow-y-auto">
        {#each filteredEntries as entry}
          <div class="p-4">
            <div class="flex items-start justify-between">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <p class="font-medium truncate">
                    {entry.description || "No description"}
                  </p>
                  {#if entry.billable}
                    <DollarSign class="w-4 h-4 text-bright-green" />
                  {/if}
                </div>
                <div class="flex items-center gap-3 text-sm text-fg-muted mt-1">
                  {#if entry.project}
                    <span class="flex items-center gap-1">
                      <span
                        class="w-2 h-2 rounded-full"
                        style="background-color: {entry.project.color}"
                      ></span>
                      {entry.project.name}
                    </span>
                  {/if}
                  {#if entry.tags.length > 0}
                    <span class="flex items-center gap-1">
                      {#each entry.tags as tag}
                        <span
                          class="px-1.5 py-0.5 bg-bg-tertiary rounded text-xs"
                          >{tag.name}</span
                        >
                      {/each}
                    </span>
                  {/if}
                </div>
              </div>
              <div class="text-right ml-4">
                <p class="font-semibold">{entry.formattedDuration}</p>
                <p class="text-sm text-fg-muted">
                  {formatShortDate(entry.start_at)}
                </p>
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</PageLayout>
