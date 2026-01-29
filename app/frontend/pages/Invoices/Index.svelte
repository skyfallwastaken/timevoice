<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import { page } from '@inertiajs/svelte'
  import { useForm } from '@inertiajs/svelte'
  import { FileText, DollarSign, Plus, Download, Clock, Settings, Check, X, Building2, ChevronDown, ChevronUp } from 'lucide-svelte'

  type Client = {
    id: number
    name: string
    billing_address: string | null
  }

  type Invoice = {
    id: number
    status: string
    total_cents: number
    period_start: string
    period_end: string
    issued_on: string | null
    total_amount: string
    line_count: number
    client: {
      id: number
      name: string
    }
  }

  type UnbilledEntry = {
    id: number
    description: string
    duration_seconds: number
    billable: boolean
    start_at: string
    formattedDuration: string
    hours: number
    project: {
      id: number
      name: string
    } | null
    tags: Array<{
      id: number
      name: string
    }>
  }

  type InvoiceSettings = {
    billable_rate_cents: number
    sender_name: string
    sender_address: string | null
  }

  let invoices = $derived($page.props.invoices as Invoice[] || [])
  let clients = $derived($page.props.clients as Client[] || [])
  let unbilledEntries = $derived($page.props.unbilledEntries as UnbilledEntry[] || [])
  let invoiceSettings = $derived($page.props.invoiceSettings as InvoiceSettings || { billable_rate_cents: 0, sender_name: '', sender_address: null })

  let showCreateForm = $state(false)
  let showSettings = $state(false)
  let expandedInvoiceId: number | null = $state(null)

  // Invoice creation form - initialize with default values
  let createForm = useForm({
    client_id: '',
    period_start: '',
    period_end: '',
    rate_cents: 0
  })

  // Update rate when invoiceSettings changes
  $effect(() => {
    if (invoiceSettings.billable_rate_cents) {
      createForm.data.rate_cents = invoiceSettings.billable_rate_cents
    }
  })

  function handleCreateInvoice() {
    $createForm.post('/invoices', {
      onSuccess: () => {
        createForm.reset()
        showCreateForm = false
      }
    })
  }

  function formatRate(cents: number): string {
    return (cents / 100).toFixed(2)
  }

  function formatDate(dateStr: string): string {
    return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  }

  function toggleInvoice(invoiceId: number) {
    expandedInvoiceId = expandedInvoiceId === invoiceId ? null : invoiceId
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'draft': return 'text-fg-muted'
      case 'issued': return 'text-bright-blue'
      case 'paid': return 'text-bright-green'
      default: return 'text-fg-muted'
    }
  }

  function getStatusBg(status: string): string {
    switch (status) {
      case 'draft': return 'bg-bg-tertiary'
      case 'issued': return 'bg-bright-blue/20'
      case 'paid': return 'bg-bright-green/20'
      default: return 'bg-bg-tertiary'
    }
  }
</script>

<AppShell>
  <div class="flex-1 p-6 overflow-auto">
    <div class="max-w-6xl mx-auto space-y-6">
      <!-- Page Header -->
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <FileText class="w-6 h-6 text-bright-purple" />
          <h2 class="text-2xl font-semibold">Invoices</h2>
        </div>
        <button
          onclick={() => showCreateForm = !showCreateForm}
          class="flex items-center gap-2 px-4 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] font-medium transition-colors duration-150"
        >
          <Plus class="w-4 h-4" />
          Create Invoice
        </button>
      </div>

      <!-- Flash Messages -->
      {#if $page.props.flash?.notice}
        <div class="bg-bright-green/10 border border-bright-green text-bright-green px-4 py-3 rounded-[10px]">
          {$page.props.flash.notice}
        </div>
      {/if}

      {#if $page.props.flash?.alert}
        <div class="bg-bright-red/10 border border-bright-red text-bright-red px-4 py-3 rounded-[10px]">
          {$page.props.flash.alert}
        </div>
      {/if}

      <!-- Settings Summary -->
      {#if !showSettings}
        <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
          <div class="p-4 border-b border-bg-tertiary flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Settings class="w-5 h-5 text-fg-muted" />
              <h3 class="font-semibold">Invoice Settings</h3>
            </div>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <span class="block text-sm font-medium text-fg-secondary mb-1">Default Billable Rate</span>
              <div class="flex items-center gap-2">
                <DollarSign class="w-4 h-4 text-fg-muted" />
                <span class="text-2xl font-semibold">{formatRate(invoiceSettings.billable_rate_cents)}</span>
                <span class="text-fg-muted">/hour</span>
              </div>
            </div>
            <div>
              <span class="block text-sm font-medium text-fg-secondary mb-1">Sender Name</span>
              <p class="text-fg-primary">{invoiceSettings.sender_name || 'Not configured'}</p>
            </div>
            {#if invoiceSettings.sender_address}
              <div class="md:col-span-2">
                <span class="block text-sm font-medium text-fg-secondary mb-1">Sender Address</span>
                <p class="text-fg-primary text-sm">{invoiceSettings.sender_address}</p>
              </div>
            {/if}
          </div>
          <div class="mt-4 pt-4 border-t border-bg-tertiary">
            <a 
              href="/settings/workspace" 
              class="text-sm text-bright-purple hover:text-accent-purple transition-colors duration-150"
            >
              Edit invoice settings in Workspace Settings →
            </a>
          </div>
        </div>
      {/if}

      <!-- Invoice Creation Form -->
      {#if showCreateForm}
        <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-6 animate-slide-in">
          <div class="flex items-center gap-3 mb-4">
            <Plus class="w-5 h-5 text-bright-purple" />
            <h3 class="font-semibold">Create New Invoice</h3>
          </div>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div>
              <label for="invoice-client" class="block text-sm font-medium text-fg-secondary mb-1">Client</label>
              <select
                id="invoice-client"
                bind:value={$createForm.client_id}
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-purple transition-colors duration-150"
              >
                <option value="">Select a client...</option>
                {#each clients as client}
                  <option value={client.id}>{client.name}</option>
                {/each}
              </select>
              {#if $createForm.errors.client_id}
                <p class="mt-1 text-sm text-bright-red">{$createForm.errors.client_id}</p>
              {/if}
            </div>
            <div>
              <label for="invoice-rate" class="block text-sm font-medium text-fg-secondary mb-1">Billable Rate ($/hour)</label>
              <input
                id="invoice-rate"
                type="number"
                bind:value={$createForm.rate_cents}
                step="1"
                min="0"
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-purple transition-colors duration-150"
              />
              <p class="mt-1 text-xs text-fg-muted">Rate in cents. Default from invoice settings.</p>
            </div>
            <div>
              <label for="invoice-start" class="block text-sm font-medium text-fg-secondary mb-1">Period Start</label>
              <input
                id="invoice-start"
                type="date"
                bind:value={$createForm.period_start}
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-purple transition-colors duration-150"
              />
              {#if $createForm.errors.period_start}
                <p class="mt-1 text-sm text-bright-red">{$createForm.errors.period_start}</p>
              {/if}
            </div>
            <div>
              <label for="invoice-end" class="block text-sm font-medium text-fg-secondary mb-1">Period End</label>
              <input
                id="invoice-end"
                type="date"
                bind:value={$createForm.period_end}
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-purple transition-colors duration-150"
              />
              {#if $createForm.errors.period_end}
                <p class="mt-1 text-sm text-bright-red">{$createForm.errors.period_end}</p>
              {/if}
            </div>
          </div>

          <div class="flex justify-end gap-3">
            <button
              onclick={() => showCreateForm = false}
              class="px-4 py-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
            >
              Cancel
            </button>
            <button
              onclick={handleCreateInvoice}
              disabled={$createForm.processing}
              class="flex items-center gap-2 px-4 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] font-medium transition-colors duration-150 disabled:opacity-50"
            >
              <Plus class="w-4 h-4" />
              {$createForm.processing ? 'Creating...' : 'Create Invoice'}
            </button>
          </div>
        </div>
      {/if}

      <!-- Unbilled Entries Section -->
      {#if unbilledEntries.length > 0}
        <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
          <div class="p-4 border-b border-bg-tertiary">
            <div class="flex items-center gap-2">
              <Clock class="w-5 h-5 text-bright-yellow" />
              <h3 class="font-semibold">Unbilled Time Entries ({unbilledEntries.length})</h3>
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
                    <p class="font-medium truncate">{entry.description || 'No description'}</p>
                    {#if entry.billable}
                      <DollarSign class="w-4 h-4 text-bright-green" />
                    {/if}
                  </div>
                  <div class="flex items-center gap-3 text-sm text-fg-muted mt-1">
                    {#if entry.project}
                      <span class="flex items-center gap-1">
                        <span class="w-2 h-2 rounded-full" style="background-color: {entry.project.color}"></span>
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

      <!-- Invoices List -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
        <div class="p-4 border-b border-bg-tertiary">
          <h3 class="font-semibold">All Invoices ({invoices.length})</h3>
        </div>

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
                  onkeydown={(e) => e.key === 'Enter' && toggleInvoice(invoice.id)}
                >
                  <div class="flex items-center gap-4">
                    <div class="w-12 h-12 rounded-[10px] {getStatusBg(invoice.status)} flex items-center justify-center">
                      <FileText class="w-6 h-6 {getStatusColor(invoice.status)}" />
                    </div>
                    <div>
                      <div class="flex items-center gap-2">
                        <p class="font-medium">Invoice #{invoice.id}</p>
                        <span class="px-2 py-0.5 text-xs rounded-full {getStatusBg(invoice.status)} {getStatusColor(invoice.status)} capitalize">
                          {invoice.status}
                        </span>
                      </div>
                      <p class="text-sm text-fg-muted">
                        {invoice.client.name} • {formatDate(invoice.period_start)} - {formatDate(invoice.period_end)}
                      </p>
                    </div>
                  </div>
                  <div class="flex items-center gap-4">
                    <div class="text-right">
                      <p class="font-semibold text-lg">{invoice.total_amount}</p>
                      <p class="text-sm text-fg-muted">{invoice.line_count} line items</p>
                    </div>
                    {#if expandedInvoiceId === invoice.id}
                      <ChevronUp class="w-5 h-5 text-fg-muted" />
                    {:else}
                      <ChevronDown class="w-5 h-5 text-fg-muted" />
                    {/if}
                  </div>
                </div>

                <!-- Expanded Details -->
                {#if expandedInvoiceId === invoice.id}
                  <div class="mt-4 pt-4 border-t border-bg-tertiary space-y-4">
                    <div class="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <span class="text-fg-muted">Issued:</span>
                        <span class="ml-2">{invoice.issued_on ? formatDate(invoice.issued_on) : 'Not issued'}</span>
                      </div>
                      <div>
                        <span class="text-fg-muted">Status:</span>
                        <span class="ml-2 capitalize">{invoice.status}</span>
                      </div>
                    </div>
                    
                    <div class="flex gap-2">
                      <a
                        href="/invoices/{invoice.id}"
                        class="flex items-center gap-2 px-4 py-2 bg-bg-tertiary hover:bg-bg-quaternary rounded-[10px] text-fg-primary transition-colors duration-150"
                      >
                        <FileText class="w-4 h-4" />
                        View Details
                      </a>
                      {#if invoice.status === 'draft'}
                        <form action="/invoices/{invoice.id}/issue" method="POST" class="inline">
                          <button
                            type="submit"
                            class="flex items-center gap-2 px-4 py-2 bg-bright-blue hover:bg-accent-blue text-bg-primary rounded-[10px] transition-colors duration-150"
                          >
                            <Check class="w-4 h-4" />
                            Issue Invoice
                          </button>
                        </form>
                      {/if}
                      {#if invoice.status !== 'paid'}
                        <form action="/invoices/{invoice.id}/mark_paid" method="POST" class="inline">
                          <button
                            type="submit"
                            class="flex items-center gap-2 px-4 py-2 bg-bright-green hover:bg-accent-green text-bg-primary rounded-[10px] transition-colors duration-150"
                          >
                            <Check class="w-4 h-4" />
                            Mark Paid
                          </button>
                        </form>
                      {/if}
                    </div>
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  </div>
</AppShell>
