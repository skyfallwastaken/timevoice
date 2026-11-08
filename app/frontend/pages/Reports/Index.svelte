<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { page, router } from "@inertiajs/svelte";
  import DatePicker from "../../components/DatePicker.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import FormField from "../../components/FormField.svelte";
  import SelectInput from "../../components/SelectInput.svelte";
  import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
  import {
    BarChart3,
    CalendarDays,
    DollarSign,
    Clock,
    Filter,
    ChevronDown,
    ChevronLeft,
    ChevronRight,
    ChevronUp,
  } from "@lucide/svelte";
  import { formatHours, formatShortDate, toDateString } from "../../lib/format";
  import { routes } from "../../lib/routes";
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
    bucket: "day" | "week" | "month";
    daily: Record<string, DayBreakdown>;
    by_project: Record<string, ProjectBreakdown>;
    by_client: Record<string, ClientBreakdown>;
  };

  type DateRange = { start: Date; end: Date };

  let entries = $derived((page.props.entries as TimeEntry[]) || []);
  let totals = $derived(
    (page.props.totals as Totals) || {
      total: 0,
      billable: 0,
      non_billable: 0,
      bucket: "day",
      daily: {},
      by_project: {},
      by_client: {},
    },
  );

  let projects = $derived((page.props.projects as Project[]) || []);

  function maxTotal(groups: Record<string, { total: number }>): number {
    return Math.max(1, ...Object.values(groups).map((g) => g.total));
  }

  let dailyEntries = $derived(Object.entries(totals.daily));
  let maxDailySeconds = $derived(maxTotal(totals.daily));
  let maxProjectSeconds = $derived(maxTotal(totals.by_project));
  let maxClientSeconds = $derived(maxTotal(totals.by_client));

  let selectedProjectId = $state(
    (page.props.projectId as string | null)?.toString() ?? "",
  );
  let showFilters = $state(!!page.props.projectId);

  const parseDate = (value: string) => new Date(`${value}T00:00:00`);
  const addDays = (date: Date, days: number) =>
    new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
  const monthRange = (year: number, month: number, months: number) => ({
    start: new Date(year, month, 1),
    end: new Date(year, month + months, 0),
  });

  let range = $derived.by(() => {
    const dates = page.props.dateRange as { start: string; end: string };
    return { start: parseDate(dates.start), end: parseDate(dates.end) };
  });

  const initialRange = page.props.dateRange as { start: string; end: string };
  let startDate = $state<Date | null>(parseDate(initialRange.start));
  let endDate = $state<Date | null>(parseDate(initialRange.end));

  // Weeks start on Monday, like Rails' beginning_of_week and the Timer page.
  function thisWeek(): DateRange {
    const today = new Date();
    const start = addDays(today, -((today.getDay() + 6) % 7));
    return { start, end: addDays(start, 6) };
  }

  const presets: { label: string; range: () => DateRange }[] = [
    { label: "This week", range: thisWeek },
    {
      label: "Last week",
      range: () => {
        const { start } = thisWeek();
        return { start: addDays(start, -7), end: addDays(start, -1) };
      },
    },
    {
      label: "This month",
      range: () =>
        monthRange(new Date().getFullYear(), new Date().getMonth(), 1),
    },
    {
      label: "Last month",
      range: () =>
        monthRange(new Date().getFullYear(), new Date().getMonth() - 1, 1),
    },
    {
      label: "This quarter",
      range: () => {
        const now = new Date();
        return monthRange(
          now.getFullYear(),
          now.getMonth() - (now.getMonth() % 3),
          3,
        );
      },
    },
    {
      label: "This year",
      range: () => monthRange(new Date().getFullYear(), 0, 12),
    },
  ];

  const sameRange = (a: DateRange, b: DateRange) =>
    toDateString(a.start) === toDateString(b.start) &&
    toDateString(a.end) === toDateString(b.end);

  let activePreset = $derived(
    presets.find((preset) => sameRange(preset.range(), range))?.label,
  );

  function formatPeriod({ start, end }: DateRange): string {
    const withYear = (date: Date) =>
      date.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
      });
    if (toDateString(start) === toDateString(end)) return withYear(start);
    const startLabel =
      start.getFullYear() === end.getFullYear()
        ? formatShortDate(`${toDateString(start)}T00:00:00`)
        : withYear(start);
    return `${startLabel} – ${withYear(end)}`;
  }

  let periodLabel = $derived(formatPeriod(range));

  // Whole months step by their month count; anything else by its day count.
  // Steps from the requested range, so quick repeated clicks add up.
  function shiftRange(direction: number) {
    const start = startDate ?? range.start;
    const end = endDate ?? range.end;
    if (start.getDate() === 1 && addDays(end, 1).getDate() === 1) {
      const months =
        (end.getFullYear() - start.getFullYear()) * 12 +
        end.getMonth() -
        start.getMonth() +
        1;
      visit(
        monthRange(
          start.getFullYear(),
          start.getMonth() + direction * months,
          months,
        ),
      );
    } else {
      const days = Math.round((end.getTime() - start.getTime()) / 86400000) + 1;
      visit({
        start: addDays(start, direction * days),
        end: addDays(end, direction * days),
      });
    }
  }

  // Once a visit completes, the server's range is the source of truth again.
  $effect(() => {
    startDate = range.start;
    endDate = range.end;
  });

  let dateTimer: ReturnType<typeof setTimeout> | undefined;

  // A pending date change must not run after another visit starts or the
  // page is left, or it would navigate back to Reports.
  $effect(() => {
    const stop = router.on("start", () => clearTimeout(dateTimer));
    return () => {
      stop();
      clearTimeout(dateTimer);
    };
  });

  function visit(next: DateRange) {
    clearTimeout(dateTimer);
    startDate = next.start;
    endDate = next.end;
    const auth = page.props.auth as { workspace: { hashid: string } };
    router.get(
      routes.reports.index(auth.workspace.hashid),
      {
        start_date: toDateString(next.start),
        end_date: toDateString(next.end),
        project_id: selectedProjectId || undefined,
      },
      { preserveState: true, preserveScroll: true, replace: true },
    );
  }

  function applyDates() {
    clearTimeout(dateTimer);
    dateTimer = setTimeout(() => {
      if (startDate && endDate && startDate <= endDate) {
        visit({ start: startDate, end: endDate });
      }
    }, 300);
  }

  function formatDayOfWeek(dateStr: string): string {
    return new Date(`${dateStr}T00:00:00`).toLocaleDateString("en-US", {
      weekday: "short",
    });
  }

  const bucketTitle = { day: "Daily", week: "Weekly", month: "Monthly" };

  function bucketLabel(dateStr: string): string {
    if (totals.bucket === "month") {
      return parseDate(dateStr).toLocaleDateString("en-US", {
        month: "short",
        year: "numeric",
      });
    }
    const short = formatShortDate(`${dateStr}T00:00:00`);
    return totals.bucket === "week" ? `Week of ${short}` : short;
  }

  // Past a month of bars, label only every few so they don't overlap.
  let labelEvery = $derived(
    dailyEntries.length > 31 ? Math.ceil(dailyEntries.length / 10) : 1,
  );

  let selectedProjectName = $derived(
    projects.find((p) => String(p.id) === String(selectedProjectId))?.name,
  );
</script>

<PageLayout title="Reports" icon={BarChart3} iconColor="text-bright-purple">
  {#snippet headerActions()}
    <div
      class="flex flex-1 sm:flex-none min-w-0 items-center h-9 rounded-[10px] border border-bg-tertiary bg-bg-secondary"
    >
      <button
        type="button"
        class="grid place-items-center w-9 h-full rounded-l-[9px] text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors"
        aria-label="Previous period"
        onclick={() => shiftRange(-1)}
      >
        <ChevronLeft class="size-4" aria-hidden="true" />
      </button>
      <DropdownMenu.Root>
        <DropdownMenu.Trigger
          class="flex flex-1 min-w-0 items-center justify-center gap-2 h-full px-3 border-x border-bg-tertiary text-sm font-medium font-tabular whitespace-nowrap hover:bg-bg-tertiary data-[state=open]:bg-bg-tertiary transition-colors"
          aria-label="Report period: {periodLabel}. Choose a preset"
          title={periodLabel}
        >
          <CalendarDays
            class="hidden sm:block size-4 shrink-0 text-fg-muted"
            aria-hidden="true"
          />
          {#if activePreset}
            <span class="hidden sm:inline">{activePreset}</span>
            <span class="hidden sm:inline text-fg-muted font-normal">·</span>
          {/if}
          <span class="truncate">{periodLabel}</span>
          <ChevronDown
            class="size-4 shrink-0 text-fg-muted"
            aria-hidden="true"
          />
        </DropdownMenu.Trigger>
        <DropdownMenu.Content sideOffset={6} align="end" class="w-48">
          <DropdownMenu.RadioGroup
            value={activePreset ?? ""}
            onValueChange={(label) => {
              const preset = presets.find((p) => p.label === label);
              if (preset) visit(preset.range());
            }}
          >
            {#each presets as preset}
              <DropdownMenu.RadioItem
                value={preset.label}
                closeOnSelect
                class="px-2 py-1.5 rounded-[6px] data-[state=checked]:text-bright-purple"
              >
                {preset.label}
              </DropdownMenu.RadioItem>
            {/each}
          </DropdownMenu.RadioGroup>
          <DropdownMenu.Separator />
          <DropdownMenu.Item
            class="px-2 py-1.5 rounded-[6px] text-fg-secondary"
            onSelect={() => (showFilters = true)}
          >
            Custom range…
          </DropdownMenu.Item>
        </DropdownMenu.Content>
      </DropdownMenu.Root>
      <button
        type="button"
        class="grid place-items-center w-9 h-full rounded-r-[9px] text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors"
        aria-label="Next period"
        onclick={() => shiftRange(1)}
      >
        <ChevronRight class="size-4" aria-hidden="true" />
      </button>
    </div>
    <Button
      variant="secondary"
      class="bg-bg-secondary"
      aria-label="Filters"
      onclick={() => (showFilters = !showFilters)}
    >
      <Filter class="w-4 h-4" />
      <span class="hidden sm:inline">Filters</span>
      {#if showFilters}
        <ChevronUp class="w-4 h-4" />
      {:else}
        <ChevronDown class="w-4 h-4" />
      {/if}
    </Button>
  {/snippet}

  {#if showFilters}
    <SectionCard class="animate-slide-in" bodyClass="p-4">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
        <FormField id="report-start" label="Start Date">
          {#snippet children({ describedBy })}
            <DatePicker
              id="report-start"
              bind:value={
                () => startDate,
                (value) => {
                  startDate = value;
                  applyDates();
                }
              }
              max={endDate}
              placeholder="Select start date"
              aria-describedby={describedBy}
            />
          {/snippet}
        </FormField>
        <FormField id="report-end" label="End Date">
          {#snippet children({ describedBy })}
            <DatePicker
              id="report-end"
              bind:value={
                () => endDate,
                (value) => {
                  endDate = value;
                  applyDates();
                }
              }
              min={startDate}
              placeholder="Select end date"
              aria-describedby={describedBy}
            />
          {/snippet}
        </FormField>
        <FormField id="report-project" label="Filter by Project">
          {#snippet children({ describedBy })}
            <SelectInput
              id="report-project"
              tone="purple"
              bind:value={selectedProjectId}
              onchange={() =>
                visit({
                  start: startDate ?? range.start,
                  end: endDate ?? range.end,
                })}
              aria-describedby={describedBy}
            >
              <option value="">All Projects</option>
              {#each projects as project}
                <option value={project.id}>{project.name}</option>
              {/each}
            </SelectInput>
          {/snippet}
        </FormField>
      </div>
    </SectionCard>
  {/if}

  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
      <div class="flex items-center gap-2 text-fg-muted mb-2">
        <Clock class="w-4 h-4" />
        <span class="text-sm">Total Hours</span>
      </div>
      <p class="text-2xl font-semibold">{formatHours(totals.total)}</p>
    </div>

    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
      <div class="flex items-center gap-2 text-bright-green mb-2">
        <DollarSign class="w-4 h-4" />
        <span class="text-sm">Billable Hours</span>
      </div>
      <p class="text-2xl font-semibold text-bright-green">
        {formatHours(totals.billable)}
      </p>
    </div>

    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
      <div class="flex items-center gap-2 text-fg-muted mb-2">
        <Clock class="w-4 h-4" />
        <span class="text-sm">Non-Billable Hours</span>
      </div>
      <p class="text-2xl font-semibold">
        {formatHours(totals.non_billable)}
      </p>
    </div>
  </div>

  {#if entries.length > 0}
    <SectionCard title={`${bucketTitle[totals.bucket]} Hours`} bodyClass="p-4">
      <div
        class="flex items-stretch h-48 {dailyEntries.length > 31
          ? 'gap-0.5'
          : 'gap-2'}"
      >
        {#each dailyEntries as [date, data], i}
          <div
            class="@container flex-1 flex flex-col items-center gap-2 min-w-0"
            title={`${bucketLabel(date)}: ${formatHours(data.total)} (${formatHours(data.billable)} billable)`}
          >
            <div class="w-full flex-1 flex flex-col justify-end pt-5">
              {#if data.total > 0}
                <div
                  class="relative w-full"
                  style="height: {(data.total / maxDailySeconds) * 100}%"
                >
                  <span
                    class="absolute bottom-full inset-x-0 mb-1 text-center text-xs text-fg-muted font-tabular hidden @min-[3rem]:block"
                  >
                    {formatHours(data.total)}
                  </span>
                  <div
                    class="h-full rounded-t bg-fg-dim overflow-hidden flex flex-col justify-end"
                  >
                    <div
                      class="bg-bright-green"
                      style="height: {(data.billable / data.total) * 100}%"
                    ></div>
                  </div>
                </div>
              {:else}
                <div class="h-0.5 w-full rounded-full bg-bg-tertiary"></div>
              {/if}
            </div>
            <span
              class="h-4 text-xs text-fg-muted whitespace-nowrap {labelEvery > 1
                ? 'self-start'
                : ''}"
            >
              {#if labelEvery > 1}
                {#if i % labelEvery === 0}
                  {totals.bucket === "month"
                    ? bucketLabel(date)
                    : formatShortDate(`${date}T00:00:00`)}
                {/if}
              {:else if totals.bucket === "day"}
                <span class="hidden @min-[3rem]:inline"
                  >{formatDayOfWeek(date)}</span
                >
                {parseDate(date).getDate()}
              {:else if totals.bucket === "week"}
                <span class="hidden @min-[3rem]:inline"
                  >{formatShortDate(`${date}T00:00:00`)}</span
                >
                <span class="@min-[3rem]:hidden"
                  >{parseDate(date).getDate()}</span
                >
              {:else}
                {parseDate(date).toLocaleDateString("en-US", {
                  month: "short",
                })}
              {/if}
            </span>
          </div>
        {/each}
      </div>
      <div
        class="flex items-center justify-center gap-4 mt-4 text-xs text-fg-muted"
      >
        <span class="flex items-center gap-1.5">
          <span class="w-3 h-3 rounded-sm bg-bright-green"></span> Billable
        </span>
        <span class="flex items-center gap-1.5">
          <span class="w-3 h-3 rounded-sm bg-fg-dim"></span> Non-billable
        </span>
      </div>
    </SectionCard>

    <SectionCard title={`${bucketTitle[totals.bucket]} Breakdown`}>
      <div class="divide-y divide-bg-tertiary">
        {#each dailyEntries.filter(([, data]) => data.total > 0) as [date, data]}
          <div class="p-4 flex items-center justify-between text-sm">
            {#if totals.bucket === "day"}
              <div class="flex items-center gap-3">
                <div class="text-center min-w-12">
                  <span class="block text-xs text-fg-muted"
                    >{formatDayOfWeek(date)}</span
                  >
                  <span class="block text-lg font-semibold"
                    >{parseDate(date).getDate()}</span
                  >
                </div>
                <span class="text-fg-muted"
                  >{formatShortDate(`${date}T00:00:00`)}</span
                >
              </div>
            {:else}
              <span class="font-medium">{bucketLabel(date)}</span>
            {/if}
            <div class="flex items-center gap-4">
              <div class="text-right">
                <span class="text-bright-green"
                  >{formatHours(data.billable)} billable</span
                >
              </div>
              <span class="font-medium font-tabular"
                >{formatHours(data.total)}</span
              >
            </div>
          </div>
        {/each}
      </div>
    </SectionCard>
  {/if}

  {#if Object.keys(totals.by_project).length > 0}
    <SectionCard title="Breakdown by Project">
      <div class="divide-y divide-bg-tertiary">
        {#each Object.entries(totals.by_project) as [projectName, data]}
          <div class="p-4 text-sm">
            <div class="flex items-center justify-between">
              <span class="font-medium">{projectName}</span>
              <div class="flex items-center gap-4">
                <span class="text-bright-green"
                  >{formatHours(data.billable)} billable</span
                >
                <span class="font-medium font-tabular"
                  >{formatHours(data.total)}</span
                >
              </div>
            </div>
            <div class="mt-2 h-1.5 rounded-full bg-bg-tertiary overflow-hidden">
              <div
                class="h-full bg-bright-purple rounded-full"
                style="width: {(data.total / maxProjectSeconds) * 100}%"
              ></div>
            </div>
          </div>
        {/each}
      </div>
    </SectionCard>
  {/if}

  {#if Object.keys(totals.by_client).length > 0}
    <SectionCard title="Breakdown by Client">
      <div class="divide-y divide-bg-tertiary">
        {#each Object.entries(totals.by_client) as [clientName, data]}
          <div class="p-4 text-sm">
            <div class="flex items-center justify-between">
              <span class="font-medium">{clientName}</span>
              <div class="flex items-center gap-4">
                <span class="text-bright-green"
                  >{formatHours(data.billable)} billable</span
                >
                <span class="font-medium font-tabular"
                  >{formatHours(data.total)}</span
                >
              </div>
            </div>
            <div class="mt-2 h-1.5 rounded-full bg-bg-tertiary overflow-hidden">
              <div
                class="h-full bg-bright-blue rounded-full"
                style="width: {(data.total / maxClientSeconds) * 100}%"
              ></div>
            </div>
          </div>
        {/each}
      </div>
    </SectionCard>
  {/if}

  <SectionCard title={`Time Entries (${entries.length})`}>
    {#if entries.length === 0}
      <EmptyState
        icon={Clock}
        title="No time entries"
        description={`Nothing was tracked${selectedProjectName ? ` on ${selectedProjectName}` : ""} for ${periodLabel}.`}
        actionLabel={activePreset === "This week" ? null : "Show this week"}
        onAction={() => visit(thisWeek())}
      />
    {:else}
      <div class="divide-y divide-bg-tertiary max-h-150 overflow-y-auto">
        {#each entries as entry}
          <div class="p-4 text-sm">
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
                          class="px-1.5 py-0.5 bg-bg-tertiary rounded text-xs font-medium"
                          >{tag.name}</span
                        >
                      {/each}
                    </span>
                  {/if}
                </div>
              </div>
              <div class="text-right ml-4">
                <p class="font-medium font-tabular">
                  {entry.formattedDuration}
                </p>
                <p class="text-sm text-fg-muted">
                  {formatShortDate(entry.start_at)}
                </p>
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </SectionCard>
</PageLayout>
