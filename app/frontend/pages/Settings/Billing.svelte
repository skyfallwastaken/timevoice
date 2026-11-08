<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { page, Link } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { DollarSign } from "@lucide/svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import SettingsTabs from "../../components/SettingsTabs.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import TextArea from "../../components/TextArea.svelte";
  import { formatRate, parseRate } from "../../lib/format";
  import { routes } from "../../lib/routes";
  import { renderMarkdown } from "../../lib/markdown";

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);
  let flash = $derived(page.props.flash || {});
  let canEdit = $derived(!!page.props.canEdit);

  let form = useForm({
    sender_name: (page.props.invoiceSettings as any)?.sender_name || "",
    sender_address: (page.props.invoiceSettings as any)?.sender_address || "",
    billable_rate_cents:
      (page.props.invoiceSettings as any)?.billable_rate_cents || 0,
    notes: (page.props.invoiceSettings as any)?.notes || "",
  });

  const notesMaxLength = page.props.notesMaxLength as number;
  let notesMode = $state<"write" | "preview">(
    page.props.canEdit === false ? "preview" : "write",
  );

  let rateInputValue = $state(
    formatRate((page.props.invoiceSettings as any)?.billable_rate_cents || 0),
  );

  function saveSettings() {
    form.patch(routes.settings.updateBilling(workspaceId), {
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
    <SettingsTabs {workspaceId} active="billing" />
  </SectionCard>

  <SectionCard
    title="Invoice Settings"
    description="Configure default settings for invoices generated from your time entries."
    bodyClass="p-4"
  >
    <fieldset class="space-y-6" disabled={!canEdit}>
      {#if !canEdit}
        <p class="text-sm text-fg-muted">
          Only workspace admins can change billing settings.
        </p>
      {/if}
      <FormField
        id="sender-name"
        label="Sender Name"
        description="This name will appear as the sender on your invoices."
        error={form.errors.sender_name}
      >
        {#snippet children({ describedBy })}
          <TextInput
            id="sender-name"
            tone="purple"
            bind:value={form.sender_name}
            placeholder="Your name or company name"
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <FormField
        id="sender-address"
        label="Sender Address"
        description="This address will appear on invoices as the sender's address."
        error={form.errors.sender_address}
      >
        {#snippet children({ describedBy })}
          <TextArea
            id="sender-address"
            tone="purple"
            bind:value={form.sender_address}
            placeholder="Your billing address"
            rows={3}
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <FormField
        id="billable-rate"
        label="Default Billable Rate ($/hour)"
        description="This rate will be used as the default when creating invoices."
      >
        {#snippet children()}
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
                (form.billable_rate_cents = parseRate(e.currentTarget.value))}
              placeholder="0.00"
              class="pl-8 pr-4"
            />
          </div>
        {/snippet}
      </FormField>

      <FormField
        id="invoice-notes"
        label="Invoice Notes"
        description="Printed under the totals on new invoices, e.g. payment terms or bank details. Markdown works; check Preview to see how it prints."
        error={form.errors.notes}
      >
        {#snippet children({ describedBy })}
          <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
            <div
              class="flex items-center h-8 p-0.5 rounded-lg bg-bg-primary border border-bg-tertiary"
              role="group"
              aria-label="Notes editor mode"
            >
              {#each [{ key: "write", label: "Write" }, { key: "preview", label: "Preview" }] as const as option (option.key)}
                <button
                  type="button"
                  aria-pressed={notesMode === option.key}
                  class="inline-flex items-center h-full px-2.5 rounded-[5px] text-sm font-medium transition-colors duration-150 {notesMode ===
                  option.key
                    ? 'bg-bg-tertiary text-fg-primary'
                    : 'text-fg-muted hover:text-fg-primary'}"
                  onclick={() => (notesMode = option.key)}
                >
                  {option.label}
                </button>
              {/each}
            </div>
            <span class="text-xs text-fg-muted tabular-nums">
              {form.notes.length.toLocaleString()} / {notesMaxLength.toLocaleString()}
            </span>
          </div>
          <div class="grid">
            <TextArea
              id="invoice-notes"
              tone="purple"
              bind:value={form.notes}
              placeholder={"**Payment due within 30 days.**\n- Bank: Monzo\n- Sort code: 04-00-04\n- Account: 12345678"}
              rows={8}
              maxlength={notesMaxLength}
              aria-describedby={describedBy}
              class="[grid-area:1/1] {notesMode === 'preview'
                ? 'invisible'
                : ''}"
            />
            {#if notesMode === "preview"}
              <div
                class="[grid-area:1/1] rounded-[10px] bg-white px-6 py-5 text-sm text-[#666]"
                role="region"
                aria-label="Invoice notes preview"
              >
                <p class="mb-2 text-xs text-[#666]">Notes</p>
                {#if form.notes.trim()}
                  <div
                    class="prose prose-sm prose-quoteless max-w-none text-inherit prose-headings:text-[#1a1a1a] prose-headings:text-sm prose-headings:mt-0 prose-headings:mb-2 prose-strong:text-inherit prose-p:my-2 prose-ul:my-2 prose-ol:my-2 prose-li:my-0.5 prose-a:text-[#6366F1] prose-code:text-[#1a1a1a] prose-code:font-[inherit] prose-code:font-normal prose-code:before:content-none prose-code:after:content-none prose-blockquote:text-inherit prose-blockquote:font-normal prose-blockquote:not-italic prose-hr:my-3 [&>:first-child]:mt-0 [&>:last-child]:mb-0"
                  >
                    {@html renderMarkdown(form.notes)}
                  </div>
                {:else}
                  <p class="italic">Nothing to preview yet.</p>
                {/if}
              </div>
            {/if}
          </div>
        {/snippet}
      </FormField>

      <div class="flex justify-end pt-4">
        <Button tone="purple" onclick={saveSettings} disabled={form.processing}>
          {form.processing ? "Saving..." : "Save Settings"}
        </Button>
      </div>
    </fieldset>
  </SectionCard>

  <SectionCard title="About Invoice Settings" bodyClass="p-4">
    <div class="space-y-2 text-sm text-fg-muted">
      <p>
        <strong class="font-medium text-fg-primary">Sender Information:</strong>
        This appears at the top of your invoices as the "From" address.
      </p>
      <p>
        <strong class="font-medium text-fg-primary">Default Rate:</strong>
        When you create an invoice, this rate is automatically applied to billable
        time entries. You can override it per-invoice if needed.
      </p>
      <p>
        <strong class="font-medium text-fg-primary">Invoice Notes:</strong>
        Copied onto each invoice when it is created, so changing them later doesn't
        alter invoices you've already sent. Markdown works for
        <code class="text-fg-secondary">**bold**</code>,
        <code class="text-fg-secondary">*italic*</code>,
        <code class="text-fg-secondary">- lists</code> and
        <code class="text-fg-secondary">[links](https://…)</code>, and line
        breaks are kept as you type them.
      </p>
      <p>
        <strong class="font-medium text-fg-primary">Client Addresses:</strong>
        Client billing addresses are managed in the <Link
          href={routes.clients.index(workspaceId)}
          class="text-bright-purple hover:text-accent-purple transition-colors duration-150"
          >Clients</Link
        > section.
      </p>
    </div>
  </SectionCard>
</PageLayout>
