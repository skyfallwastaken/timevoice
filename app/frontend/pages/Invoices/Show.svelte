<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import Modal from "../../components/Modal.svelte";
  import Button from "../../components/Button.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import DeleteButton from "../../components/DeleteButton.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import TextArea from "../../components/TextArea.svelte";
  import { Link, page, router } from "@inertiajs/svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import {
    FileText,
    ArrowLeft,
    Calendar,
    Download,
    Mail,
    Trash2,
    Edit2,
    Check,
    X,
    Ellipsis,
    Undo2,
    FilePen,
  } from "@lucide/svelte";
  import {
    formatCurrency,
    formatDate,
    formatRate,
    getStatusClasses,
    parseRate,
    toDateString,
  } from "../../lib/format";
  import { renderMarkdown } from "../../lib/markdown";
  import { routes } from "../../lib/routes";
  import Turnstile from "../../components/Turnstile.svelte";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
  import type {
    FlashData,
    Invoice,
    InvoiceLine,
    InvoiceSender,
    InvoiceStatus,
  } from "../../types";

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);

  let invoice = $derived(page.props.invoice as Invoice);
  let sender = $derived(page.props.sender as InvoiceSender);
  let canEditLines = $derived(
    !!page.props.canEdit && invoice.status === "draft",
  );
  const userEmail = (page.props.auth as any)?.user?.email || "";
  const isDevMode = page.props.rails_env === "development";

  const linkButtonClass =
    "inline-flex items-center justify-center gap-2 rounded-[10px] transition-colors duration-150 font-medium h-9 px-4 text-sm bg-bg-secondary border border-bg-tertiary hover:bg-bg-tertiary text-fg-primary";

  let emailModalOpen = $state(false);
  let emailRecipients = $state("");
  let emailMessage = $state("");
  let ccSelf = $state(false);
  let sending = $state(false);
  let showLetterOpenerHint = $state(false);
  let turnstileToken = $state("");
  let showDeleteModal = $state(false);
  let showMarkUnpaidModal = $state(false);
  let showRevertToDraftModal = $state(false);
  let editingNumber = $state(false);
  let editInvoiceNumber = $state(0);

  let editingLineId = $state<number | null>(null);
  let lineDescription = $state("");
  let lineHours = $state("");
  let lineRate = $state("");
  let savingLine = $state(false);
  let lineToRemove = $state<InvoiceLine | null>(null);
  let showRemoveLineModal = $state(false);

  let lineAmountPreview = $derived(
    Math.round((parseFloat(lineHours) || 0) * parseRate(lineRate)),
  );

  // A second tap while the delete is in flight would 404 on the deleted invoice.
  let deleting = false;
  function deleteInvoice() {
    if (deleting) return;
    deleting = true;
    showDeleteModal = false;
    router.delete(routes.invoices.delete(workspaceId, invoice.hashid), {
      onFinish: () => (deleting = false),
    });
  }

  function saveInvoiceNumber() {
    router.patch(
      routes.invoices.update(workspaceId, invoice.hashid),
      { invoice: { invoice_number: editInvoiceNumber } },
      {
        preserveScroll: true,
        onSuccess: () => {
          editingNumber = false;
        },
      },
    );
  }

  function updateInvoiceStatus(status: InvoiceStatus) {
    router
      .optimistic<{ invoice: Invoice }>((props) => ({
        invoice: {
          ...props.invoice,
          status,
          ...(status === "issued" &&
            props.invoice.status === "draft" && {
              issued_on: toDateString(new Date()),
            }),
        },
      }))
      .patch(
        routes.invoices.update(workspaceId, invoice.hashid),
        { invoice: { status } },
        { preserveScroll: true },
      );
  }

  function openEmailModal() {
    emailRecipients = invoice.client.email || "";
    emailMessage = "";
    ccSelf = false;
    turnstileToken = "";
    emailModalOpen = true;
  }

  function startEditingInvoiceNumber() {
    editInvoiceNumber = invoice.invoice_number;
    editingNumber = true;
  }

  function cancelInvoiceNumberEdit() {
    editInvoiceNumber = invoice.invoice_number;
    editingNumber = false;
  }

  function startEditingLine(line: InvoiceLine) {
    lineDescription = line.description;
    lineHours = Number(line.qty_hours).toFixed(2);
    lineRate = formatRate(line.rate_cents ?? 0);
    editingLineId = line.id;
  }

  function saveLine() {
    if (editingLineId === null) return;

    savingLine = true;
    router.patch(
      routes.invoices.line(workspaceId, invoice.hashid, editingLineId),
      {
        line: {
          description: lineDescription,
          qty_hours: lineHours,
          rate_cents:
            String(lineRate ?? "").trim() === "" ? null : parseRate(lineRate),
        },
      },
      {
        preserveScroll: true,
        onSuccess: (visit) => {
          if (!(visit.props.flash as FlashData | undefined)?.alert) {
            editingLineId = null;
          }
        },
        onFinish: () => {
          savingLine = false;
        },
      },
    );
  }

  function removeLine() {
    if (!lineToRemove) return;

    router.delete(
      routes.invoices.line(workspaceId, invoice.hashid, lineToRemove.id),
      { preserveScroll: true },
    );
    showRemoveLineModal = false;
  }

  function sendEmail() {
    if (!emailRecipients.trim()) return;

    sending = true;
    router.post(
      routes.invoices.sendEmail(workspaceId, invoice.hashid),
      {
        recipients: emailRecipients,
        cc_self: ccSelf ? "true" : "false",
        message: emailMessage,
        "cf-turnstile-response": turnstileToken,
      },
      {
        onSuccess: () => {
          emailModalOpen = false;
          if (isDevMode) {
            showLetterOpenerHint = true;
          }
        },
        onFinish: () => {
          sending = false;
          turnstileToken = "";
        },
      },
    );
  }
</script>

<PageLayout
  title={`Invoice #${invoice.invoice_number}`}
  icon={FileText}
  iconColor="text-bright-purple"
>
  {#snippet breadcrumb()}
    <Link
      href={routes.invoices.index(workspaceId)}
      class="inline-flex items-center gap-1.5 text-sm text-fg-muted hover:text-fg-primary transition-colors duration-150"
    >
      <ArrowLeft class="w-4 h-4" aria-hidden="true" />
      Invoices
    </Link>
  {/snippet}

  {#snippet headerActions()}
    <div class="flex flex-wrap items-center sm:justify-end gap-2">
      {#if showLetterOpenerHint && isDevMode}
        <a
          href={routes.devTools.letterOpener}
          target="_blank"
          class="inline-flex items-center gap-2 h-9 px-4 text-sm bg-bright-green/10 border-2 border-dashed border-bright-green/60 text-bright-green rounded-[10px] hover:bg-bright-green/20 transition-colors duration-150"
        >
          <Mail class="w-4 h-4" />
          View Sent Email
        </a>
      {/if}
      {#if editingNumber}
        <form
          class="flex items-center gap-2"
          onsubmit={(e) => {
            e.preventDefault();
            saveInvoiceNumber();
          }}
        >
          <label for="invoice-number" class="text-sm text-fg-muted"
            >Invoice #</label
          >
          <div class="w-24">
            <TextInput
              id="invoice-number"
              type="number"
              bind:value={editInvoiceNumber}
              tone="purple"
              min="1"
            />
          </div>
          <Button variant="secondary" type="submit" aria-label="Save number">
            <Check class="w-4 h-4" />
          </Button>
          <Button
            variant="ghost"
            type="button"
            aria-label="Cancel"
            onclick={cancelInvoiceNumberEdit}
          >
            <X class="w-4 h-4" />
          </Button>
        </form>
      {:else}
        {#if invoice.status === "draft"}
          <Button tone="purple" onclick={() => updateInvoiceStatus("issued")}>
            <Check class="w-4 h-4" />
            Issue invoice
          </Button>
        {:else if invoice.status === "issued"}
          <Button variant="secondary" onclick={openEmailModal}>
            <Mail class="w-4 h-4" />
            Email
          </Button>
          <Button tone="green" onclick={() => updateInvoiceStatus("paid")}>
            <Check class="w-4 h-4" />
            Mark paid
          </Button>
        {:else}
          <a
            href={routes.invoices.pdf(workspaceId, invoice.hashid)}
            target="_blank"
            class={linkButtonClass}
          >
            <FileText class="w-4 h-4" aria-hidden="true" />
            Download PDF
          </a>
          <Button tone="purple" onclick={openEmailModal}>
            <Mail class="w-4 h-4" />
            Email
          </Button>
        {/if}
        <DropdownMenu.Root>
          <DropdownMenu.Trigger>
            {#snippet child({ props })}
              <Button
                {...props}
                variant="secondary"
                class="px-2.5"
                aria-label="More invoice actions"
              >
                <Ellipsis class="w-4 h-4" aria-hidden="true" />
              </Button>
            {/snippet}
          </DropdownMenu.Trigger>
          <DropdownMenu.Content align="end" class="w-auto min-w-48">
            {#if invoice.status === "draft"}
              <DropdownMenu.Item
                class="px-3 py-2 gap-2"
                onSelect={openEmailModal}
              >
                <Mail aria-hidden="true" /> Email
              </DropdownMenu.Item>
              <DropdownMenu.Item
                class="px-3 py-2 gap-2"
                onSelect={() => updateInvoiceStatus("paid")}
              >
                <Check aria-hidden="true" /> Mark paid
              </DropdownMenu.Item>
            {/if}
            {#if invoice.status === "paid" && page.props.canEdit}
              <DropdownMenu.Item
                class="px-3 py-2 gap-2"
                onSelect={() => (showMarkUnpaidModal = true)}
              >
                <Undo2 aria-hidden="true" /> Mark as unpaid
              </DropdownMenu.Item>
            {/if}
            {#if invoice.status === "issued" && page.props.canEdit}
              <DropdownMenu.Item
                class="px-3 py-2 gap-2"
                onSelect={() => (showRevertToDraftModal = true)}
              >
                <FilePen aria-hidden="true" /> Revert to draft
              </DropdownMenu.Item>
            {/if}
            {#if invoice.status !== "paid"}
              <DropdownMenu.Item class="px-3 py-2 gap-2">
                {#snippet child({ props })}
                  <a
                    {...props}
                    href={routes.invoices.pdf(workspaceId, invoice.hashid)}
                    target="_blank"
                  >
                    <FileText aria-hidden="true" />
                    Download PDF
                  </a>
                {/snippet}
              </DropdownMenu.Item>
            {/if}
            <DropdownMenu.Item class="px-3 py-2 gap-2">
              {#snippet child({ props })}
                <a
                  {...props}
                  href={routes.invoices.csv(workspaceId, invoice.hashid)}
                >
                  <Download aria-hidden="true" />
                  Export CSV
                </a>
              {/snippet}
            </DropdownMenu.Item>
            {#if canEditLines}
              <DropdownMenu.Item
                class="px-3 py-2 gap-2"
                onSelect={startEditingInvoiceNumber}
              >
                <Edit2 aria-hidden="true" /> Edit number
              </DropdownMenu.Item>
            {/if}
            {#if invoice.status === "draft"}
              <DropdownMenu.Separator />
              <DropdownMenu.Item
                variant="destructive"
                class="px-3 py-2 gap-2"
                onSelect={() => (showDeleteModal = true)}
              >
                <Trash2 aria-hidden="true" /> Delete
              </DropdownMenu.Item>
            {/if}
          </DropdownMenu.Content>
        </DropdownMenu.Root>
      {/if}
    </div>
  {/snippet}

  <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
    <div
      class="p-4 border-b border-bg-tertiary flex items-start justify-between gap-4"
    >
      <div class="min-w-0">
        <div class="flex items-center gap-2">
          <h3 class="font-semibold truncate">{invoice.client.name}</h3>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-full capitalize {getStatusClasses(
              invoice.status,
            )}"
          >
            {invoice.status}
          </span>
        </div>
        <div
          class="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-fg-muted"
        >
          <span class="inline-flex items-center gap-2">
            <Calendar class="w-4 h-4" />
            {formatDate(invoice.period_start)} - {formatDate(
              invoice.period_end,
            )}
          </span>
          <span
            >Issued: {invoice.status === "draft" || !invoice.issued_on
              ? "Not issued"
              : formatDate(invoice.issued_on)}</span
          >
        </div>
      </div>

      <div class="text-right">
        <div class="text-sm text-fg-muted">Total</div>
        <div class="text-2xl font-semibold">{invoice.total_amount}</div>
      </div>
    </div>

    <div class="p-4 grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div>
        <div class="text-sm text-fg-muted mb-2">From</div>
        <div class="text-sm font-medium">{sender.name}</div>
        {#if sender.address}
          <div class="mt-1 text-sm text-fg-muted whitespace-pre-line">
            {sender.address}
          </div>
        {/if}
      </div>
      <div>
        <div class="text-sm text-fg-muted mb-2">Bill to</div>
        <div class="text-sm font-medium">{invoice.client.name}</div>
        {#if invoice.client.billing_address}
          <div class="mt-1 text-sm text-fg-muted whitespace-pre-line">
            {invoice.client.billing_address}
          </div>
        {:else}
          <div class="mt-1 text-sm text-fg-muted italic">
            No billing address
          </div>
        {/if}
      </div>
    </div>

    <div class="border-t border-bg-tertiary">
      <!-- relative keeps the sr-only header inside the scroll box. -->
      <div class="relative p-4 overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="text-fg-muted">
            <tr class="border-b border-bg-tertiary">
              <th class="text-left font-medium py-2">Description</th>
              <th class="text-right font-medium py-2 pl-2 sm:pl-4">Hours</th>
              <th class="hidden sm:table-cell text-right font-medium py-2 pl-4">
                Rate
              </th>
              <th class="text-right font-medium py-2 pl-2 sm:pl-4">Amount</th>
              {#if canEditLines}
                <th class="py-2 pl-2"><span class="sr-only">Actions</span></th>
              {/if}
            </tr>
          </thead>
          <tbody class="divide-y divide-bg-tertiary">
            {#each invoice.lines as line (line.id)}
              {#if editingLineId === line.id}
                <tr>
                  <!-- Phones edit in one stacked cell; the row's columns are too narrow. -->
                  <td colspan="4" class="sm:hidden py-3">
                    <div class="space-y-2">
                      <TextInput
                        tone="purple"
                        bind:value={lineDescription}
                        aria-label="Description"
                        onkeydown={(e) => e.key === "Enter" && saveLine()}
                      />
                      <div class="grid grid-cols-2 gap-2">
                        <TextInput
                          type="number"
                          tone="purple"
                          step="0.01"
                          min="0.01"
                          bind:value={lineHours}
                          aria-label="Hours"
                          placeholder="Hours"
                          class="text-right font-tabular"
                          onkeydown={(e) => e.key === "Enter" && saveLine()}
                        />
                        <div class="relative">
                          <span
                            class="absolute left-3 top-1/2 -translate-y-1/2 text-fg-muted"
                            aria-hidden="true">$</span
                          >
                          <TextInput
                            type="number"
                            tone="purple"
                            step="0.01"
                            min="0"
                            bind:value={lineRate}
                            aria-label="Rate per hour"
                            class="pl-6 text-right font-tabular"
                            onkeydown={(e) => e.key === "Enter" && saveLine()}
                          />
                        </div>
                      </div>
                      <div class="flex items-center gap-1">
                        <span class="mr-auto font-tabular text-fg-muted"
                          >{formatCurrency(lineAmountPreview)}</span
                        >
                        <Button
                          size="sm"
                          variant="ghost"
                          onclick={() => (editingLineId = null)}
                        >
                          Cancel
                        </Button>
                        <Button
                          size="sm"
                          tone="purple"
                          disabled={savingLine}
                          onclick={saveLine}
                        >
                          Save
                        </Button>
                      </div>
                    </div>
                  </td>
                  <td class="hidden sm:table-cell py-2 pr-2">
                    <TextInput
                      tone="purple"
                      bind:value={lineDescription}
                      aria-label="Description"
                      class="min-w-48"
                      onkeydown={(e) => e.key === "Enter" && saveLine()}
                    />
                  </td>
                  <td class="hidden sm:table-cell py-2 pl-2">
                    <div class="w-24 ml-auto">
                      <TextInput
                        type="number"
                        tone="purple"
                        step="0.01"
                        min="0.01"
                        bind:value={lineHours}
                        aria-label="Hours"
                        class="text-right font-tabular"
                        onkeydown={(e) => e.key === "Enter" && saveLine()}
                      />
                    </div>
                  </td>
                  <td class="hidden sm:table-cell py-2 pl-2">
                    <div class="relative w-28 ml-auto">
                      <span
                        class="absolute left-3 top-1/2 -translate-y-1/2 text-fg-muted"
                        aria-hidden="true">$</span
                      >
                      <TextInput
                        type="number"
                        tone="purple"
                        step="0.01"
                        min="0"
                        bind:value={lineRate}
                        aria-label="Rate per hour"
                        class="pl-6 text-right font-tabular"
                        onkeydown={(e) => e.key === "Enter" && saveLine()}
                      />
                    </div>
                  </td>
                  <td
                    class="hidden sm:table-cell py-2 pl-4 text-right font-tabular whitespace-nowrap text-fg-muted"
                    >{formatCurrency(lineAmountPreview)}</td
                  >
                  <td class="hidden sm:table-cell py-2 pl-2">
                    <div class="flex items-center justify-end gap-1">
                      <Button
                        size="sm"
                        tone="purple"
                        disabled={savingLine}
                        onclick={saveLine}
                      >
                        Save
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        onclick={() => (editingLineId = null)}
                      >
                        Cancel
                      </Button>
                    </div>
                  </td>
                </tr>
              {:else}
                <tr>
                  <td class="py-3 pr-2 sm:pr-4">
                    <span class="text-fg-primary"
                      >{line.description || "No description"}</span
                    >
                    <span
                      class="sm:hidden block text-xs text-fg-muted font-tabular"
                      ><span class="sr-only">Rate </span>{line.rate}</span
                    >
                  </td>
                  <td
                    class="py-3 pl-2 sm:pl-4 text-right font-tabular whitespace-nowrap"
                    >{Number(line.qty_hours).toFixed(2)}</td
                  >
                  <td
                    class="hidden sm:table-cell py-3 pl-4 text-right font-tabular whitespace-nowrap"
                    >{line.rate}</td
                  >
                  <td
                    class="py-3 pl-2 sm:pl-4 text-right font-tabular whitespace-nowrap"
                    >{line.amount}</td
                  >
                  {#if canEditLines}
                    <td class="py-1 pl-1 sm:pl-2">
                      <div class="flex items-center justify-end">
                        <IconButton
                          size="sm"
                          aria-label="Edit line"
                          onclick={() => startEditingLine(line)}
                        >
                          <Edit2 class="w-4 h-4" aria-hidden="true" />
                        </IconButton>
                        {#if invoice.lines.length > 1}
                          <DeleteButton
                            size="sm"
                            aria-label="Remove line"
                            onclick={() => {
                              lineToRemove = line;
                              showRemoveLineModal = true;
                            }}
                            onShiftClick={() => {
                              lineToRemove = line;
                              removeLine();
                            }}
                          />
                        {/if}
                      </div>
                    </td>
                  {/if}
                </tr>
              {/if}
            {/each}
          </tbody>
          <tfoot>
            <tr class="border-t border-bg-tertiary">
              <td
                colspan="3"
                class="hidden sm:table-cell pt-3 text-right text-fg-muted"
              >
                Total
              </td>
              <td colspan="2" class="sm:hidden pt-3 text-right text-fg-muted">
                Total
              </td>
              <td
                class="pt-3 pl-4 text-right font-semibold font-tabular whitespace-nowrap"
                >{invoice.total_amount}</td
              >
              {#if canEditLines}<td></td>{/if}
            </tr>
          </tfoot>
        </table>
      </div>
    </div>

    {#if invoice.notes?.trim()}
      <div class="border-t border-bg-tertiary p-4">
        <div class="text-sm text-fg-muted mb-2">Notes</div>
        <div
          class="prose prose-sm prose-quoteless max-w-none text-fg-secondary prose-headings:text-fg-primary prose-headings:text-sm prose-headings:mt-0 prose-headings:mb-2 prose-strong:text-fg-primary prose-p:my-2 prose-ul:my-2 prose-ol:my-2 prose-li:my-0.5 prose-a:text-bright-purple prose-code:text-fg-primary prose-code:font-[inherit] prose-code:font-normal prose-code:before:content-none prose-code:after:content-none prose-blockquote:text-inherit prose-blockquote:font-normal prose-blockquote:not-italic prose-hr:my-3 prose-li:marker:text-fg-muted [&>:first-child]:mt-0 [&>:last-child]:mb-0"
        >
          {@html renderMarkdown(invoice.notes)}
        </div>
      </div>
    {/if}
  </div>
</PageLayout>

<Modal
  bind:open={emailModalOpen}
  title={`Email Invoice #${invoice.invoice_number}`}
  maxWidth="max-w-lg"
>
  <form
    onsubmit={(e) => {
      e.preventDefault();
      sendEmail();
    }}
    class="space-y-4"
  >
    <FormField
      id="recipients"
      label="Recipients"
      description="Separate multiple emails with commas"
    >
      {#snippet children({ describedBy })}
        <TextInput
          id="recipients"
          tone="purple"
          bind:value={emailRecipients}
          placeholder="email@example.com, another@example.com"
          aria-describedby={describedBy}
          required
        />
      {/snippet}
    </FormField>

    <FormField id="message" label="Message (optional)">
      {#snippet children({ describedBy })}
        <TextArea
          id="message"
          tone="purple"
          bind:value={emailMessage}
          rows={4}
          placeholder="Add a personal message to include in the email..."
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>

    <div class="flex items-center gap-2">
      <Checkbox id="cc_self" bind:checked={ccSelf} />
      <label for="cc_self" class="text-sm">CC myself ({userEmail})</label>
    </div>

    <Turnstile onSuccess={(token) => (turnstileToken = token)} />

    <div class="flex justify-end gap-2 pt-2">
      <Button
        type="button"
        variant="secondary"
        onclick={() => (emailModalOpen = false)}
      >
        Cancel
      </Button>
      <Button
        type="submit"
        tone="purple"
        disabled={sending || !emailRecipients.trim()}
      >
        {sending ? "Sending..." : "Send Invoice"}
      </Button>
    </div>
  </form>
</Modal>

<ConfirmDeleteModal
  bind:open={showDeleteModal}
  title="Delete Invoice"
  itemName={`Invoice #${invoice.invoice_number}`}
  warningMessage="This action cannot be undone. This will permanently delete the invoice and unbill all associated time entries."
  onConfirm={deleteInvoice}
  onClose={() => (showDeleteModal = false)}
>
  {#snippet details()}
    <div class="text-sm text-fg-muted space-y-1">
      <p>Client: {invoice.client.name}</p>
      <p>Amount: {invoice.total_amount}</p>
    </div>
  {/snippet}
</ConfirmDeleteModal>

<ConfirmDeleteModal
  bind:open={showRemoveLineModal}
  title="Remove line"
  actionVerb="remove"
  itemName={lineToRemove?.description || "this line"}
  warningMessage="Its time entry goes back to your unbilled entries and the invoice total is recalculated."
  onConfirm={removeLine}
  onClose={() => (showRemoveLineModal = false)}
/>

<ConfirmDeleteModal
  bind:open={showMarkUnpaidModal}
  title="Mark as unpaid"
  actionVerb="reopen"
  confirmTone="purple"
  itemName={`Invoice #${invoice.invoice_number}`}
  warningMessage="It moves back to Issued and counts as unpaid again. Its number, issue date and lines don't change."
  onConfirm={() => {
    showMarkUnpaidModal = false;
    updateInvoiceStatus("issued");
  }}
  onClose={() => (showMarkUnpaidModal = false)}
/>

<ConfirmDeleteModal
  bind:open={showRevertToDraftModal}
  title="Revert to draft"
  actionVerb="revert"
  confirmTone="purple"
  itemName={`Invoice #${invoice.invoice_number}`}
  warningMessage="It becomes an editable draft again and keeps its number and lines. Issuing it again sets a new issue date. If you've already sent it, the client still has the old version."
  onConfirm={() => {
    showRevertToDraftModal = false;
    updateInvoiceStatus("draft");
  }}
  onClose={() => (showRevertToDraftModal = false)}
/>
