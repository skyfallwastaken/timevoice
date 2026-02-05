<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { page, router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { DateInput } from "date-picker-svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import ChipButton from "../../components/ChipButton.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import SelectInput from "../../components/SelectInput.svelte";
  import {
    FileText,
    DollarSign,
    Plus,
    Clock,
    Settings,
    Check,
    ChevronDown,
    ChevronUp,
  } from "lucide-svelte";
  import {
    formatRate,
    parseRate,
    formatDate,
    getStatusColor,
    getStatusBg,
    toDateString,
    getRelativeDateRange,
    getLastMonthRange,
  } from "../../lib/format";

  type Client = {
    id: number;
    name: string;
    billing_address: string | null;
  };

  type Invoice = {
    id: number;
    hashid: string;
    status: string;
    total_cents: number;
    period_start: string;
    period_end: string;
    issued_on: string | null;
    total_amount: string;
    line_count: number;
    client: {
      id: number;
      name: string;
    };
  };

  type UnbilledEntry = {
    id: number;
    description: string;
    duration_seconds: number;
    billable: boolean;
    start_at: string;
    formattedDuration: string;
    hours: number;
    project: {
      id: number;
      name: string;
      color: string;
    } | null;
    tags: Array<{
      id: number;
      name: string;
    }>;
  };

  type InvoiceSettings = {
    billable_rate_cents: number;
    sender_name: string;
    sender_address: string | null;
  };

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);
  let invoices = $derived(($page.props.invoices as Invoice[]) || []);
  let clients = $derived(($page.props.clients as Client[]) || []);
  let unbilledEntries = $derived(
    ($page.props.unbilledEntries as UnbilledEntry[]) || [],
  );
  let invoiceSettings = $derived(
    ($page.props.invoiceSettings as InvoiceSettings) || {
      billable_rate_cents: 0,
      sender_name: "",
      sender_address: null,
    },
  );

  let showCreateForm = $state(false);
  let expandedInvoiceId: number | null = $state(null);

  let periodStartDate = $state<Date | null>(null);
  let periodEndDate = $state<Date | null>(null);

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
    rate_cents:
      ($page.props.invoiceSettings as InvoiceSettings)?.billable_rate_cents ||
      0,
  });

  $effect(() => {
    $createForm.period_start = periodStartDate
      ? toDateString(periodStartDate)
      : "";
    $createForm.period_end = periodEndDate ? toDateString(periodEndDate) : "";
  });

  let canCreateInvoice = $derived(
    !!$createForm.client_id &&
      !!periodStartDate &&
      !!periodEndDate &&
      periodStartDate.getTime() <= periodEndDate.getTime() &&
      !$createForm.processing,
  );

  function handleCreateInvoice() {
    $createForm.post(`/${workspaceId}/invoices`, {
      onSuccess: () => {
        $createForm.reset();
        periodStartDate = null;
        periodEndDate = null;
        showCreateForm = false;
      },
    });
  }

  function toggleInvoice(invoiceId: number) {
    expandedInvoiceId = expandedInvoiceId === invoiceId ? null : invoiceId;
  }

  function updateInvoiceStatus(invoiceId: number, status: string) {
    router.patch(
      `/${workspaceId}/invoices/${invoiceId}`,
      { invoice: { status } },
      { preserveScroll: true },
    );
  }
</script>

<PageLayout
  title="Invoices"
  icon={FileText}
  iconColor="text-bright-purple"
  variant="wide"
  flash={$page.props.flash}
>
  {#snippet headerActions()}
    <Button tone="purple" onclick={() => (showCreateForm = !showCreateForm)}>
      <Plus class="w-4 h-4" />
      Create Invoice
    </Button>
  {/snippet}

  <SectionCard title="Invoice Settings" icon={Settings} bodyClass="p-4">
    <div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <span class="block text-sm font-medium text-fg-secondary mb-1"
            >Default Billable Rate</span
          >
          <div class="flex items-center gap-2">
            <DollarSign class="w-4 h-4 text-fg-muted" />
            <span class="text-2xl font-semibold"
              >{formatRate(invoiceSettings.billable_rate_cents)}</span
            >
            <span class="text-fg-muted">/hour</span>
          </div>
        </div>
        <div>
          <span class="block text-sm font-medium text-fg-secondary mb-1"
            >Sender Name</span
          >
          <p class="text-fg-primary">
            {invoiceSettings.sender_name || "Not configured"}
          </p>
        </div>
        {#if invoiceSettings.sender_address}
          <div class="md:col-span-2">
            <span class="block text-sm font-medium text-fg-secondary mb-1"
              >Sender Address</span
            >
            <p class="text-fg-primary text-sm whitespace-pre-line">
              {invoiceSettings.sender_address}
            </p>
          </div>
        {/if}
      </div>
    </div>
    {#snippet footer()}
      <a
        href="/{workspaceId}/settings/billing"
        class="text-sm text-bright-purple hover:text-accent-purple transition-colors duration-150"
      >
        Edit invoice settings in Billing Settings →
      </a>
    {/snippet}
  </SectionCard>

  {#if showCreateForm}
    <SectionCard
      class="animate-slide-in"
      headerless
      bodyClass="p-0"
    >
      <form
        class="p-6"
        onsubmit={(e) => {
          e.preventDefault();
          if (canCreateInvoice) handleCreateInvoice();
        }}
      >
        <div class="flex items-center gap-3 mb-4">
          <Plus class="w-5 h-5 text-bright-purple" />
          <h3 class="font-semibold">Create New Invoice</h3>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <FormField id="invoice-client" label="Client" error={$createForm.errors.client_id}>
            {#snippet children({ describedBy })}
              <SelectInput
                id="invoice-client"
                tone="purple"
                bind:value={$createForm.client_id}
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
            description="Defaults from invoice settings."
          >
            {#snippet children({ describedBy })}
              <TextInput
                id="invoice-rate"
                type="number"
                tone="purple"
                value={formatRate($createForm.rate_cents)}
                oninput={(e) =>
                  ($createForm.rate_cents = parseRate(e.currentTarget.value))}
                step="0.01"
                min="0"
                aria-describedby={describedBy}
              />
            {/snippet}
          </FormField>
          <FormField
            id="invoice-start"
            label="Period Start"
            error={$createForm.errors.period_start}
          >
            {#snippet children({ describedBy })}
              <div class="date-input-gruvbox" aria-describedby={describedBy}>
                <DateInput
                  bind:value={periodStartDate}
                  max={periodEndDate ?? undefined}
                  placeholder="Select start date"
                  format="yyyy-MM-dd"
                  closeOnSelection={true}
                />
              </div>
            {/snippet}
          </FormField>
          <FormField
            id="invoice-end"
            label="Period End"
            error={$createForm.errors.period_end}
          >
            {#snippet children({ describedBy })}
              <div class="date-input-gruvbox" aria-describedby={describedBy}>
                <DateInput
                  bind:value={periodEndDate}
                  min={periodStartDate ?? undefined}
                  placeholder="Select end date"
                  format="yyyy-MM-dd"
                  closeOnSelection={true}
                />
              </div>
            {/snippet}
          </FormField>
        </div>

        <div class="mb-4">
          <span class="block text-sm font-medium text-fg-secondary mb-2"
            >Quick Select</span
          >
          <div class="flex flex-wrap gap-2">
            <ChipButton type="button" onclick={() => setDateRange(7)}>
              Last Week
            </ChipButton>
            <ChipButton type="button" onclick={() => setDateRange(14)}>
              Last 2 Weeks
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
            {$createForm.processing ? "Creating..." : "Create Invoice"}
          </Button>
        </div>
      </form>
    </SectionCard>
  {/if}

  {#if unbilledEntries.length > 0}
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <div class="flex items-center gap-2">
          <Clock class="w-5 h-5 text-bright-yellow" />
          <h3 class="font-semibold">
            Unbilled Time Entries ({unbilledEntries.length})
          </h3>
        </div>
        <p class="text-sm text-fg-muted mt-1">
          These entries haven't been included in any invoice yet.
        </p>
      </div>
      <div class="divide-y divide-bg-tertiary max-h-96 overflow-y-auto">
        {#each unbilledEntries as entry}
          <div class="p-4 flex items-center justify-between">
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
                <span>{entry.formattedDuration}</span>
                <span>({entry.hours.toFixed(2)} hours)</span>
              </div>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <SectionCard title={`All Invoices (${invoices.length})`} bodyClass="p-4">
    {#if invoices.length === 0}
      <div class="p-8 text-center text-fg-muted">
        <FileText class="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>No invoices yet. Create your first invoice above!</p>
      </div>
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each invoices as invoice}
          <div class="p-4">
            <div
              class="flex items-center justify-between cursor-pointer"
              onclick={() => toggleInvoice(invoice.id)}
              role="button"
              tabindex="0"
              onkeydown={(e) => e.key === "Enter" && toggleInvoice(invoice.id)}
            >
              <div class="flex items-center gap-4">
                <div
                  class="w-12 h-12 rounded-[10px] {getStatusBg(
                    invoice.status,
                  )} flex items-center justify-center"
                >
                  <FileText class="w-6 h-6 {getStatusColor(invoice.status)}" />
                </div>
                <div>
                  <div class="flex items-center gap-2">
                    <p class="font-medium">Invoice #{invoice.id}</p>
                    <span
                      class="px-2 py-0.5 text-xs rounded-full {getStatusBg(
                        invoice.status,
                      )} {getStatusColor(invoice.status)} capitalize"
                    >
                      {invoice.status}
                    </span>
                  </div>
                  <p class="text-sm text-fg-muted">
                    {invoice.client.name} • {formatDate(invoice.period_start)}
                    - {formatDate(invoice.period_end)}
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-4">
                <div class="text-right">
                  <p class="font-semibold text-lg">{invoice.total_amount}</p>
                  <p class="text-sm text-fg-muted">
                    {invoice.line_count} line items
                  </p>
                </div>
                {#if expandedInvoiceId === invoice.id}
                  <ChevronUp class="w-5 h-5 text-fg-muted" />
                {:else}
                  <ChevronDown class="w-5 h-5 text-fg-muted" />
                {/if}
              </div>
            </div>

            {#if expandedInvoiceId === invoice.id}
              <div class="mt-4 pt-4 border-t border-bg-tertiary space-y-4">
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-fg-muted">Issued:</span>
                    <span class="ml-2"
                      >{invoice.issued_on
                        ? formatDate(invoice.issued_on)
                        : "Not issued"}</span
                    >
                  </div>
                  <div>
                    <span class="text-fg-muted">Status:</span>
                    <span class="ml-2 capitalize">{invoice.status}</span>
                  </div>
                </div>

                <div class="flex flex-col sm:flex-row gap-2">
                  <a
                    href={`/${workspaceId}/invoices/${invoice.hashid}`}
                    class="flex items-center justify-center gap-2 px-4 py-2 bg-bg-tertiary hover:bg-bg-quaternary rounded-[10px] text-fg-primary transition-colors duration-150"
                  >
                    <FileText class="w-4 h-4" />
                    View Details
                  </a>
                  {#if invoice.status === "draft"}
                    <button
                      type="button"
                      class="flex items-center justify-center gap-2 px-4 py-2 bg-bright-blue hover:bg-accent-blue text-bg-primary rounded-[10px] transition-colors duration-150"
                      onclick={() => updateInvoiceStatus(invoice.id, "issued")}
                    >
                      <Check class="w-4 h-4" />
                      Issue Invoice
                    </button>
                  {/if}
                  {#if invoice.status !== "paid"}
                    <button
                      type="button"
                      class="flex items-center justify-center gap-2 px-4 py-2 bg-bright-green hover:bg-accent-green text-bg-primary rounded-[10px] transition-colors duration-150"
                      onclick={() => updateInvoiceStatus(invoice.id, "paid")}
                    >
                      <Check class="w-4 h-4" />
                      Mark Paid
                    </button>
                  {/if}
                </div>
              </div>
            {/if}
          </div>
        {/each}
      </div>
    {/if}
  </SectionCard>
</PageLayout>
