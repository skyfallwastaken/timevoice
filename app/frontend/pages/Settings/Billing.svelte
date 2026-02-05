<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { page, Link } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { DollarSign } from "lucide-svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import TextArea from "../../components/TextArea.svelte";
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
  <SectionCard class="overflow-hidden" bodyClass="p-0">
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
  </SectionCard>

  <SectionCard
    title="Invoice Settings"
    description="Configure default settings for invoices generated from your time entries."
    bodyClass="p-4"
  >
    <div class="space-y-6">
      <FormField
        id="sender-name"
        label="Sender Name"
        description="This name will appear as the sender on your invoices."
        error={$form.errors.sender_name}
      >
        {#snippet children({ describedBy })}
          <TextInput
            id="sender-name"
            tone="purple"
            bind:value={$form.sender_name}
            placeholder="Your name or company name"
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <FormField
        id="sender-address"
        label="Sender Address"
        description="This address will appear on invoices as the sender's address."
        error={$form.errors.sender_address}
      >
        {#snippet children({ describedBy })}
          <TextArea
            id="sender-address"
            tone="purple"
            bind:value={$form.sender_address}
            placeholder="Your billing address"
            rows={3}
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

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
          <TextInput
            id="billable-rate"
            type="number"
            tone="purple"
            step="0.01"
            min="0"
            bind:value={rateInputValue}
            onchange={(e) =>
              ($form.billable_rate_cents = parseRate(e.currentTarget.value))}
            placeholder="0.00"
            class="pl-8 pr-4"
          />
        </div>
        <p class="text-sm text-fg-muted mt-1">
          This rate will be used as the default when creating invoices.
        </p>
      </div>

      <div class="flex justify-end pt-4">
        <Button
          tone="purple"
          onclick={saveSettings}
          disabled={$form.processing}
        >
          {$form.processing ? "Saving..." : "Save Settings"}
        </Button>
      </div>
    </div>
  </SectionCard>

  <SectionCard title="About Invoice Settings" bodyClass="p-4">
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
  </SectionCard>
</PageLayout>
