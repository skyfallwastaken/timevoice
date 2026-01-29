<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import { page } from '@inertiajs/svelte'
  import { useForm } from '@inertiajs/svelte'
  import { DollarSign, Building } from 'lucide-svelte'
  import EmptyState from '../../components/EmptyState.svelte'

  let invoiceSettings = $derived($page.props.invoiceSettings || {})
  let flash = $derived($page.props.flash || {})

  // Initialize form with default values
  let form = useForm({
    sender_name: '',
    sender_address: '',
    billable_rate_cents: 0
  })

  // Update form when invoiceSettings changes
  $effect(() => {
    form.data.sender_name = invoiceSettings.sender_name || ''
    form.data.sender_address = invoiceSettings.sender_address || ''
    form.data.billable_rate_cents = invoiceSettings.billable_rate_cents || 0
  })

  function saveSettings() {
    $form.patch('/settings/billing', {
      preserveScroll: true,
      onSuccess: () => {
        // Flash message handled by server
      }
    })
  }

  function formatRate(cents: number): string {
    return (cents / 100).toFixed(2)
  }

  function parseRate(value: string): number {
    const num = parseFloat(value)
    return isNaN(num) ? 0 : Math.round(num * 100)
  }
</script>

<AppShell>
  <div class="flex-1 p-6 overflow-auto">
    <div class="max-w-4xl mx-auto space-y-6">
      <!-- Page Header -->
      <div class="flex items-center gap-3">
        <DollarSign class="w-6 h-6 text-bright-purple" />
        <h2 class="text-2xl font-semibold">Billing Settings</h2>
      </div>

      <!-- Flash Messages -->
      {#if flash.notice}
        <div class="bg-bright-green/10 border border-bright-green text-bright-green px-4 py-3 rounded-[10px]">
          {flash.notice}
        </div>
      {/if}

      {#if flash.alert}
        <div class="bg-bright-red/10 border border-bright-red text-bright-red px-4 py-3 rounded-[10px]">
          {flash.alert}
        </div>
      {/if}

      <!-- Billing Settings Form -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
        <div class="p-4 border-b border-bg-tertiary">
          <h3 class="font-semibold">Invoice Settings</h3>
          <p class="text-sm text-fg-muted mt-1">
            Configure default settings for invoices generated from your time entries.
          </p>
        </div>
        
        <div class="p-4 space-y-6">
          <!-- Sender Name -->
          <div>
            <label for="sender-name" class="block text-sm font-medium text-fg-secondary mb-2">
              Sender Name
            </label>
            <input
              id="sender-name"
              type="text"
              bind:value={$form.sender_name}
              placeholder="Your name or company name"
              class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-purple transition-colors duration-150"
            />
            <p class="text-sm text-fg-muted mt-1">
              This name will appear as the sender on your invoices.
            </p>
            {#if $form.errors.sender_name}
              <p class="text-sm text-bright-red mt-1">{$form.errors.sender_name}</p>
            {/if}
          </div>

          <!-- Sender Address -->
          <div>
            <label for="sender-address" class="block text-sm font-medium text-fg-secondary mb-2">
              Sender Address
            </label>
            <textarea
              id="sender-address"
              bind:value={$form.sender_address}
              placeholder="Your billing address"
              rows="3"
              class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-purple transition-colors duration-150 resize-none"
            ></textarea>
            <p class="text-sm text-fg-muted mt-1">
              This address will appear on invoices as the sender's address.
            </p>
            {#if $form.errors.sender_address}
              <p class="text-sm text-bright-red mt-1">{$form.errors.sender_address}</p>
            {/if}
          </div>

          <!-- Default Billable Rate -->
          <div>
            <label for="billable-rate" class="block text-sm font-medium text-fg-secondary mb-2">
              Default Billable Rate ($/hour)
            </label>
            <div class="relative">
              <DollarSign class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-fg-muted" />
              <input
                id="billable-rate"
                type="number"
                step="0.01"
                min="0"
                value={formatRate($form.billable_rate_cents)}
                oninput={(e) => $form.billable_rate_cents = parseRate(e.currentTarget.value)}
                placeholder="0.00"
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] pl-8 pr-4 py-2 text-fg-primary placeholder:text-fg-dim focus:border-bright-purple transition-colors duration-150"
              />
            </div>
            <p class="text-sm text-fg-muted mt-1">
              This rate will be used as the default when creating invoices.
            </p>
          </div>

          <div class="flex justify-end pt-4">
            <button
              onclick={saveSettings}
              disabled={$form.processing}
              class="px-6 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] transition-colors duration-150 font-medium disabled:opacity-50"
            >
              {$form.processing ? 'Saving...' : 'Save Settings'}
            </button>
          </div>
        </div>
      </div>

      <!-- Help Section -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
        <h3 class="font-semibold mb-3">About Invoice Settings</h3>
        <div class="space-y-2 text-sm text-fg-muted">
          <p>
            <strong class="text-fg-primary">Sender Information:</strong> 
            This appears at the top of your invoices as the "From" address.
          </p>
          <p>
            <strong class="text-fg-primary">Default Rate:</strong> 
            When you create an invoice, this rate is automatically applied to billable time entries. You can override it per-invoice if needed.
          </p>
          <p>
            <strong class="text-fg-primary">Client Addresses:</strong> 
            Client billing addresses are managed in the <a href="/clients" class="text-bright-purple hover:text-accent-purple transition-colors duration-150">Clients</a> section.
          </p>
        </div>
      </div>
    </div>
  </div>
</AppShell>
