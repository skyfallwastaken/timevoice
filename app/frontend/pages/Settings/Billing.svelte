<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { page, Link } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { DollarSign } from "lucide-svelte";
  import { formatRate, parseRate } from "../../lib/format";

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);
  let flash = $derived($page.props.flash || {});

  let form = useForm({
    sender_name: ($page.props.invoiceSettings as any)?.sender_name || "",
    sender_address: ($page.props.invoiceSettings as any)?.sender_address || "",
    billable_rate_cents:
      ($page.props.invoiceSettings as any)?.billable_rate_cents || 0,
  });

  let rateInputValue = $state(
    formatRate(($page.props.invoiceSettings as any)?.billable_rate_cents || 0),
  );

  function saveSettings() {
    $form.patch(`/${workspaceId}/settings/billing`, {
      preserveScroll: true,
    });
  }
</script>

<PageLayout
  title="Billing Settings"
  icon={DollarSign}
  iconColor="text-bright-purple"
  variant="narrow"
  {flash}
>
  <div
    class="bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
  >
    <div class="grid grid-cols-2">
      <Link
        href="/{workspaceId}/settings/workspace"
        class="px-4 py-2 text-sm font-medium text-fg-secondary hover:bg-bg-tertiary transition-colors duration-150 border-r border-bg-tertiary"
      >
        Workspace
      </Link>
      <Link
        href="/{workspaceId}/settings/billing"
        class="px-4 py-2 text-sm font-medium bg-bg-tertiary text-fg-primary"
        aria-current="page"
      >
        Billing
      </Link>
    </div>
  </div>

  <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
    <div class="p-4 border-b border-bg-tertiary">
      <h3 class="font-semibold">Invoice Settings</h3>
      <p class="text-sm text-fg-muted mt-1">
        Configure default settings for invoices generated from your time
        entries.
      </p>
    </div>

    <div class="p-4 space-y-6">
      <div>
        <label
          for="sender-name"
          class="block text-sm font-medium text-fg-secondary mb-2"
        >
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

      <div>
        <label
          for="sender-address"
          class="block text-sm font-medium text-fg-secondary mb-2"
        >
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
          <p class="text-sm text-bright-red mt-1">
            {$form.errors.sender_address}
          </p>
        {/if}
      </div>

      <div>
        <label
          for="billable-rate"
          class="block text-sm font-medium text-fg-secondary mb-2"
        >
          Default Billable Rate ($/hour)
        </label>
        <div class="relative">
          <DollarSign
            class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-fg-muted"
          />
          <input
            id="billable-rate"
            type="number"
            step="0.01"
            min="0"
            bind:value={rateInputValue}
            onchange={(e) =>
              ($form.billable_rate_cents = parseRate(e.currentTarget.value))}
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
          {$form.processing ? "Saving..." : "Save Settings"}
        </button>
      </div>
    </div>
  </div>

  <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] p-4">
    <h3 class="font-semibold mb-3">About Invoice Settings</h3>
    <div class="space-y-2 text-sm text-fg-muted">
      <p>
        <strong class="text-fg-primary">Sender Information:</strong>
        This appears at the top of your invoices as the "From" address.
      </p>
      <p>
        <strong class="text-fg-primary">Default Rate:</strong>
        When you create an invoice, this rate is automatically applied to billable
        time entries. You can override it per-invoice if needed.
      </p>
      <p>
        <strong class="text-fg-primary">Client Addresses:</strong>
        Client billing addresses are managed in the <Link
          href="/{workspaceId}/clients"
          class="text-bright-purple hover:text-accent-purple transition-colors duration-150"
          >Clients</Link
        > section.
      </p>
    </div>
  </div>
</PageLayout>
