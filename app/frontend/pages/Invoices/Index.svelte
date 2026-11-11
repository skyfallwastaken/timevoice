<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { tick, untrack } from "svelte";
  import { Link, page, router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import DatePicker from "../../components/DatePicker.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import FormField from "../../components/FormField.svelte";
  import ChipButton from "../../components/ChipButton.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import SelectInput from "../../components/SelectInput.svelte";
  import {
    FileText,
    DollarSign,
    Plus,
    Clock,
    Check,
    ChevronRight,
  } from "@lucide/svelte";
  import {
    formatCurrency,
    formatDuration,
    formatRate,
    parseRate,
    lineAmountCents,
    formatDate,
    getStatusClasses,
    toDateString,
    getRelativeDateRange,
    getLastMonthRange,
  } from "../../lib/format";
  import { routes } from "../../lib/routes";
  import type {
    Client,
    InvoiceListItem,
    InvoiceSettings,
    InvoiceStatus,
    UnbilledEntry,
  } from "../../types";

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);
  let invoices = $derived((page.props.invoices as InvoiceListItem[]) || []);
  let clients = $derived((page.props.clients as Client[]) || []);
  let unbilledEntries = $derived(
    (page.props.unbilledEntries as UnbilledEntry[]) || [],
  );
  let invoiceSettings = $derived(
    (page.props.invoiceSettings as InvoiceSettings) || {
      billable_rate_cents: 0,
      sender_name: "",
      sender_address: null,
    },
  );

  let showCreateForm = $state(false);
  let createFormEl = $state<HTMLElement | null>(null);

  let periodStartDate = $state<Date | null>(null);
  let periodEndDate = $state<Date | null>(null);
  let useAllEntries = $state(false);

  function setTodayAsDefault() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    periodEndDate = today;
  }

  function setDateRange(daysBack: number | "month") {
    const range =
      daysBack === "month"
        ? getLastMonthRange()
        : getRelativeDateRange(daysBack);
    periodStartDate = range.start;
    periodEndDate = range.end;
    useAllEntries = false;
  }

  $effect(() => {
    if (showCreateForm && !periodEndDate) {
      setTodayAsDefault();
    }
  });

  let createForm = useForm({
    client_id: "",
    period_start: "",
    period_end: "",
    rate_cents: untrack(() => invoiceSettings.billable_rate_cents) || 0,
  });

  let rateInput = $state(formatRate(createForm.rate_cents));
  let rateEdited = false;

  // An instant visit first renders cached props, so follow the workspace rate
  // when the fresh props arrive, unless the user has typed their own rate.
  $effect(() => {
    const rate = invoiceSettings.billable_rate_cents || 0;
    untrack(() => {
      createForm.defaults("rate_cents", rate);
      if (rateEdited) return;
      createForm.rate_cents = rate;
      rateInput = formatRate(rate);
    });
  });

  let clientUnbilledEntries = $derived(
    unbilledEntries.filter(
      (entry) =>
        !!createForm.client_id &&
        entry.project?.client_id === Number(createForm.client_id),
    ),
  );
  let previewEntries = $derived.by(() => {
    if (useAllEntries) return clientUnbilledEntries;
    if (!periodStartDate || !periodEndDate) return [];
    const start = toDateString(periodStartDate);
    const end = toDateString(periodEndDate);
    return clientUnbilledEntries.filter((entry) => {
      const day = entry.start_at.slice(0, 10);
      return day >= start && day <= end;
    });
  });
  let previewHours = $derived(
    previewEntries.reduce((sum, entry) => sum + entry.hours, 0),
  );
  let previewAmountCents = $derived(
    previewEntries.reduce(
      (sum, entry) => sum + lineAmountCents(entry.hours, createForm.rate_cents),
      0,
    ),
  );

  let canCreateInvoice = $derived(
    !!createForm.client_id &&
      (useAllEntries
        ? clientUnbilledEntries.length > 0
        : !!periodStartDate &&
          !!periodEndDate &&
          periodStartDate.getTime() <= periodEndDate.getTime()) &&
      !createForm.processing,
  );

  function handleCreateInvoice() {
    createForm
      .transform((data) => ({
        invoice: {
          ...data,
          all_entries: useAllEntries,
          period_start: periodStartDate ? toDateString(periodStartDate) : "",
          period_end: periodEndDate ? toDateString(periodEndDate) : "",
        },
      }))
      .post(routes.invoices.create(workspaceId), {
        onSuccess: () => {
          createForm.reset();
          rateEdited = false;
          rateInput = formatRate(createForm.rate_cents);
          periodStartDate = null;
          periodEndDate = null;
          useAllEntries = false;
          showCreateForm = false;
        },
      });
  }

  async function openCreateForm() {
    showCreateForm = true;
    await tick();
    createFormEl?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  // Issue turns into Mark paid in place, so a double tap would do both: the
  // second click of a double click is ignored, and so is any click while the
  // row's change is still saving.
  let updatingStatus = $state<string[]>([]);
  function updateInvoiceStatus(
    invoiceHashid: string,
    status: InvoiceStatus,
    event: MouseEvent,
  ) {
    if (event.detail > 1 || updatingStatus.includes(invoiceHashid)) return;
    updatingStatus = [...updatingStatus, invoiceHashid];
    router
      .optimistic<{ invoices: InvoiceListItem[] }>((props) => ({
        invoices: props.invoices.map((i) =>
          i.hashid === invoiceHashid ? { ...i, status } : i,
        ),
      }))
      .patch(
        routes.invoices.update(workspaceId, invoiceHashid),
        { invoice: { status } },
        {
          preserveScroll: true,
          onFinish: () =>
            (updatingStatus = updatingStatus.filter(
              (hashid) => hashid !== invoiceHashid,
            )),
        },
      );
  }
</script>

{#snippet previewTotal()}
  {previewHours.toFixed(2)} hours × {formatCurrency(createForm.rate_cents)}/h =
  <span class="font-semibold">{formatCurrency(previewAmountCents)}</span>
{/snippet}

<PageLayout title="Invoices" icon={FileText} iconColor="text-bright-purple">
  {#snippet headerActions()}
    {#if !showCreateForm}
      <Button tone="purple" onclick={openCreateForm}>
        <Plus class="w-4 h-4" />
        Create Invoice
      </Button>
    {/if}
  {/snippet}

  <p class="-mt-3 text-sm text-fg-muted">
    Default rate {formatCurrency(invoiceSettings.billable_rate_cents)}/h ·
    <Link
      href={routes.settings.billing(workspaceId)}
      class="text-bright-purple hover:text-accent-purple transition-colors duration-150"
    >
      Edit in Billing settings
    </Link>
  </p>

  <SectionCard title={`All Invoices (${invoices.length})`} bodyClass="p-0">
    {#if invoices.length === 0}
      <EmptyState
        icon={FileText}
        title="No invoices yet"
        description="Turn your unbilled time entries into an invoice for a client."
        actionLabel={showCreateForm ? null : "Create Invoice"}
        onAction={openCreateForm}
      />
    {:else}
      <ul class="divide-y divide-bg-tertiary">
        {#each invoices as invoice (invoice.id)}
          <li
            class="relative flex items-center gap-4 p-4 hover:bg-bg-tertiary/40 transition-[background-color] duration-150"
          >
            <div
              class="hidden sm:flex w-10 h-10 shrink-0 rounded-[10px] items-center justify-center {getStatusClasses(
                invoice.status,
              )}"
            >
              <FileText class="w-5 h-5" aria-hidden="true" />
            </div>
            <div class="min-w-0 flex-1">
              <div class="flex items-center gap-2">
                <Link
                  href={routes.invoices.show(workspaceId, invoice.hashid)}
                  class="text-sm font-medium after:absolute after:inset-0 focus-visible:outline-none focus-visible:after:ring-2 focus-visible:after:ring-bright-purple focus-visible:after:rounded-[10px]"
                >
                  Invoice #{invoice.invoice_number}
                </Link>
                <span
                  class="px-2 py-0.5 text-xs font-medium rounded-full capitalize select-none {getStatusClasses(
                    invoice.status,
                  )}"
                >
                  {invoice.status}
                </span>
              </div>
              <p class="text-sm text-fg-muted truncate">
                {invoice.client.name} • {formatDate(invoice.period_start)} - {formatDate(
                  invoice.period_end,
                )}
              </p>
            </div>
            {#if invoice.status === "draft"}
              <Button
                size="sm"
                variant="secondary"
                class="relative hidden sm:inline-flex"
                disabled={updatingStatus.includes(invoice.hashid)}
                onclick={(e) =>
                  updateInvoiceStatus(invoice.hashid, "issued", e)}
              >
                <Check class="w-4 h-4" />
                Issue
              </Button>
            {:else if invoice.status === "issued"}
              <Button
                size="sm"
                variant="secondary"
                class="relative hidden sm:inline-flex"
                disabled={updatingStatus.includes(invoice.hashid)}
                onclick={(e) => updateInvoiceStatus(invoice.hashid, "paid", e)}
              >
                <Check class="w-4 h-4" />
                Mark paid
              </Button>
            {/if}
            <div class="text-right shrink-0">
              <p class="text-sm font-semibold font-tabular">
                {invoice.total_amount}
              </p>
              <p class="text-sm text-fg-muted">
                {invoice.line_count}
                {invoice.line_count === 1 ? "line" : "lines"}
              </p>
            </div>
            <ChevronRight
              class="w-5 h-5 shrink-0 text-fg-muted"
              aria-hidden="true"
            />
          </li>
        {/each}
      </ul>
    {/if}
  </SectionCard>

  {#if showCreateForm}
    <div bind:this={createFormEl} class="scroll-mt-6">
      <SectionCard
        title="Create New Invoice"
        icon={Plus}
        iconColor="text-bright-purple"
        class="animate-slide-in"
        bodyClass="p-4"
      >
        <form
          onsubmit={(e) => {
            e.preventDefault();
            if (canCreateInvoice) handleCreateInvoice();
          }}
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <FormField
              id="invoice-client"
              label="Client"
              error={createForm.errors.client_id}
            >
              {#snippet children({ describedBy })}
                <SelectInput
                  id="invoice-client"
                  tone="purple"
                  bind:value={createForm.client_id}
                  aria-describedby={describedBy}
                >
                  <option value="">Select a client...</option>
                  {#each clients as client}
                    <option value={client.id}>{client.name}</option>
                  {/each}
                </SelectInput>
              {/snippet}
            </FormField>
            <FormField
              id="invoice-rate"
              label="Billable Rate ($/hour)"
              description={createForm.rate_cents > 0
                ? "Defaults from invoice settings."
                : "No rate set. Enter one here or set a default in Billing Settings."}
            >
              {#snippet children({ describedBy })}
                <div class="relative">
                  <DollarSign
                    class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-fg-muted"
                    aria-hidden="true"
                  />
                  <TextInput
                    id="invoice-rate"
                    type="number"
                    tone="purple"
                    bind:value={rateInput}
                    oninput={() => {
                      rateEdited = true;
                      createForm.rate_cents = parseRate(rateInput);
                    }}
                    step="0.01"
                    min="0"
                    placeholder="0.00"
                    class="pl-8 pr-4"
                    aria-describedby={describedBy}
                  />
                </div>
              {/snippet}
            </FormField>
            {#if useAllEntries}
              <div
                class="md:col-span-2 bg-bg-primary border border-bg-tertiary rounded-[10px] p-4 text-sm"
              >
                {#if !createForm.client_id}
                  <p class="text-fg-muted">
                    Select a client to see their unbilled entries.
                  </p>
                {:else if clientUnbilledEntries.length === 0}
                  <p class="text-fg-muted">
                    This client has no unbilled entries.
                  </p>
                {:else}
                  <p class="text-fg-primary">
                    All {clientUnbilledEntries.length} unbilled
                    {clientUnbilledEntries.length === 1 ? "entry" : "entries"}
                    for this client will be invoiced: {@render previewTotal()}
                  </p>
                  <p class="text-fg-muted mt-1">
                    The invoice period is set from the earliest to the latest
                    entry.
                  </p>
                {/if}
              </div>
            {:else}
              <FormField
                id="invoice-start"
                label="Period Start"
                error={createForm.errors.period_start}
              >
                {#snippet children({ describedBy })}
                  <DatePicker
                    id="invoice-start"
                    bind:value={periodStartDate}
                    max={periodEndDate}
                    placeholder="Select start date"
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>
              <FormField
                id="invoice-end"
                label="Period End"
                error={createForm.errors.period_end}
              >
                {#snippet children({ describedBy })}
                  <DatePicker
                    id="invoice-end"
                    bind:value={periodEndDate}
                    min={periodStartDate}
                    placeholder="Select end date"
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>
              {#if createForm.client_id && periodStartDate && periodEndDate}
                <div
                  class="md:col-span-2 bg-bg-primary border border-bg-tertiary rounded-[10px] p-4 text-sm"
                >
                  {#if previewEntries.length === 0}
                    <p class="text-fg-muted">
                      This client has no unbilled entries in this period.
                    </p>
                  {:else}
                    <p class="text-fg-primary">
                      {previewEntries.length} unbilled
                      {previewEntries.length === 1 ? "entry" : "entries"}
                      in this period: {@render previewTotal()}
                    </p>
                  {/if}
                </div>
              {/if}
            {/if}
          </div>

          <div class="mb-4">
            <span class="block text-sm font-medium text-fg-secondary mb-2"
              >Quick Select</span
            >
            <div class="flex flex-wrap gap-2">
              <ChipButton
                type="button"
                selected={useAllEntries}
                aria-pressed={useAllEntries}
                onclick={() => (useAllEntries = !useAllEntries)}
              >
                All Unbilled Entries
              </ChipButton>
              <ChipButton type="button" onclick={() => setDateRange(6)}>
                Last 7 Days
              </ChipButton>
              <ChipButton type="button" onclick={() => setDateRange(13)}>
                Last 14 Days
              </ChipButton>
              <ChipButton type="button" onclick={() => setDateRange("month")}>
                Last Month
              </ChipButton>
            </div>
          </div>

          <div class="flex items-center justify-end gap-3">
            <Button
              type="button"
              variant="ghost"
              onclick={() => (showCreateForm = false)}
            >
              Cancel
            </Button>
            <Button type="submit" tone="purple" disabled={!canCreateInvoice}>
              <Plus class="w-4 h-4" />
              {createForm.processing ? "Creating..." : "Create Invoice"}
            </Button>
          </div>
        </form>
      </SectionCard>
    </div>
  {/if}

  {#if unbilledEntries.length > 0}
    <SectionCard
      title={`Unbilled Time Entries (${unbilledEntries.length})`}
      description="These entries haven't been included in any invoice yet."
      icon={Clock}
      iconColor="text-bright-yellow"
      bodyClass="divide-y divide-bg-tertiary max-h-96 overflow-y-auto"
    >
      {#each unbilledEntries as entry}
        <div class="p-4 flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <p class="text-sm font-medium truncate">
                {entry.description || "No description"}
              </p>
              {#if entry.billable}
                <DollarSign class="w-4 h-4 text-bright-green" />
              {/if}
            </div>
            <div
              class="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-fg-muted mt-1"
            >
              <span>{formatDate(entry.start_at.slice(0, 10))}</span>
              {#if entry.project}
                <span class="flex items-center gap-1">
                  <span
                    class="w-2 h-2 rounded-full"
                    style="background-color: {entry.project.color}"
                  ></span>
                  {entry.project.name}
                </span>
              {/if}
              {#if entry.project?.client}
                <span>{entry.project.client.name}</span>
              {:else}
                <span class="text-bright-yellow"
                  >No client · can't be invoiced</span
                >
              {/if}
              <span>{formatDuration(entry.duration_seconds)}</span>
              <span>({entry.hours.toFixed(2)} hours)</span>
            </div>
          </div>
        </div>
      {/each}
    </SectionCard>
  {/if}
</PageLayout>
