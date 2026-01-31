<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import PageLayout from '../../components/PageLayout.svelte'
	import { page } from '@inertiajs/svelte'
	import { FileText, ArrowLeft, Calendar, Building2, Download } from 'lucide-svelte'

	const workspaceId = $derived($page.props.auth?.workspace?.id)

	type InvoiceLine = {
    id: number
    description: string | null
    qty_hours: number
    rate_cents: number
    amount_cents: number
    amount: string
    rate: string
  }

  type Invoice = {
    id: number
    hashid: string
    status: string
    period_start: string
    period_end: string
    issued_on: string | null
    total_amount: string
    client: {
      id: number
      name: string
      billing_address: string | null
    }
    lines: InvoiceLine[]
  }

  let invoice = $derived($page.props.invoice as Invoice)

  function formatDate(dateStr: string): string {
    return new Date(`${dateStr}T00:00:00`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  }

  function getStatusColor(status: string): string {
    switch (status) {
      case 'draft':
        return 'text-fg-muted bg-bg-tertiary'
      case 'issued':
        return 'text-bright-blue bg-bright-blue/20'
      case 'paid':
        return 'text-bright-green bg-bright-green/20'
      default:
        return 'text-fg-muted bg-bg-tertiary'
    }
  }
</script>

<AppShell>
  <PageLayout title={`Invoice #${invoice.id}`} icon={FileText} iconColor="text-bright-purple" variant="wide" flash={$page.props.flash}>
    {#snippet headerActions()}
      <div class="flex items-center gap-2">
        <a
          href="/{workspaceId}/invoices/{invoice.hashid}/pdf"
          target="_blank"
          class="inline-flex items-center gap-2 px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
        >
          <Download class="w-4 h-4" />
          Download PDF
        </a>
        <a
          href="/{workspaceId}/invoices"
          class="inline-flex items-center gap-2 px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
        >
          <ArrowLeft class="w-4 h-4" />
          Back
        </a>
      </div>
    {/snippet}

    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary flex items-start justify-between gap-4">
        <div class="min-w-0">
          <div class="flex items-center gap-2">
            <h3 class="font-semibold text-lg truncate">{invoice.client.name}</h3>
            <span class="px-2 py-0.5 text-xs rounded-full capitalize {getStatusColor(invoice.status)}">
              {invoice.status}
            </span>
          </div>
          <div class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-fg-muted">
            <span class="inline-flex items-center gap-2">
              <Calendar class="w-4 h-4" />
              {formatDate(invoice.period_start)} - {formatDate(invoice.period_end)}
            </span>
            <span>Issued: {invoice.issued_on ? formatDate(invoice.issued_on) : 'Not issued'}</span>
          </div>
        </div>

        <div class="text-right">
          <div class="text-sm text-fg-muted">Total</div>
          <div class="text-2xl font-semibold">{invoice.total_amount}</div>
        </div>
      </div>

      <div class="p-4 grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="bg-bg-primary border border-bg-tertiary rounded-[10px] p-4">
          <div class="flex items-center gap-2 text-fg-muted mb-2">
            <Building2 class="w-4 h-4" />
            <span class="text-sm">Client</span>
          </div>
          <div class="font-medium">{invoice.client.name}</div>
          {#if invoice.client.billing_address}
            <div class="mt-1 text-sm text-fg-muted whitespace-pre-line">{invoice.client.billing_address}</div>
          {:else}
            <div class="mt-1 text-sm text-fg-dim italic">No billing address</div>
          {/if}
        </div>

        <div class="bg-bg-primary border border-bg-tertiary rounded-[10px] p-4">
          <div class="text-sm text-fg-muted mb-2">Line Items</div>
          <div class="text-sm text-fg-muted">{invoice.lines.length} item{invoice.lines.length === 1 ? '' : 's'}</div>
        </div>
      </div>

      <div class="border-t border-bg-tertiary">
        <div class="p-4 overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="text-fg-muted">
              <tr class="border-b border-bg-tertiary">
                <th class="text-left font-medium py-2">Description</th>
                <th class="text-right font-medium py-2">Hours</th>
                <th class="text-right font-medium py-2">Rate</th>
                <th class="text-right font-medium py-2">Amount</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-bg-tertiary">
              {#each invoice.lines as line}
                <tr>
                  <td class="py-3 pr-4">
                    <span class="text-fg-primary">{line.description || 'No description'}</span>
                  </td>
                  <td class="py-3 text-right font-tabular">{Number(line.qty_hours).toFixed(2)}</td>
                  <td class="py-3 text-right font-tabular">{line.rate}</td>
                  <td class="py-3 text-right font-tabular">{line.amount}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </PageLayout>
</AppShell>
