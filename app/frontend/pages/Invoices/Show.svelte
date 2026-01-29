<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import Modal from "../../components/Modal.svelte";
  import { Link, page } from "@inertiajs/svelte";
  import { router } from "@inertiajs/svelte";
  import {
    FileText,
    ArrowLeft,
    Calendar,
    Building2,
    Download,
    Mail,
  } from "lucide-svelte";
  import { formatDate, getStatusClasses } from "../../lib/format";

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  type InvoiceLine = {
    id: number;
    description: string | null;
    qty_hours: number;
    rate_cents: number;
    amount_cents: number;
    amount: string;
    rate: string;
  };

  type Invoice = {
    id: number;
    hashid: string;
    status: string;
    period_start: string;
    period_end: string;
    issued_on: string | null;
    total_amount: string;
    client: {
      id: number;
      name: string;
      billing_address: string | null;
    };
    lines: InvoiceLine[];
  };

  let invoice = $derived($page.props.invoice as Invoice);
  const userEmail = ($page.props.auth as any)?.user?.email || "";
  const isDevMode = $page.props.rails_env === "development";

  let emailModalOpen = $state(false);
  let emailRecipients = $state("");
  let emailMessage = $state("");
  let ccSelf = $state(false);
  let sending = $state(false);
  let showLetterOpenerHint = $state(false);

  function openEmailModal() {
    emailRecipients = "";
    emailMessage = "";
    ccSelf = false;
    emailModalOpen = true;
  }

  function sendEmail() {
    if (!emailRecipients.trim()) return;

    sending = true;
    router.post(
      `/${workspaceId}/invoices/${invoice.hashid}/send_email`,
      {
        recipients: emailRecipients,
        cc_self: ccSelf ? "true" : "false",
        message: emailMessage,
      },
      {
        onFinish: () => {
          sending = false;
          emailModalOpen = false;
          if (isDevMode) {
            showLetterOpenerHint = true;
          }
        },
      },
    );
  }
</script>

<PageLayout
  title={`Invoice #${invoice.id}`}
  icon={FileText}
  iconColor="text-bright-purple"
  variant="wide"
  flash={$page.props.flash}
>
  {#snippet headerActions()}
    <div class="flex items-center gap-2">
      {#if showLetterOpenerHint && isDevMode}
        <a
          href="/letter_opener"
          target="_blank"
          class="inline-flex items-center gap-2 px-4 py-2 bg-green-950 border-2 border-dashed border-green-500 text-green-400 rounded-[10px] hover:bg-green-900 transition-colors duration-150"
        >
          <Mail class="w-4 h-4" />
          View Sent Email
        </a>
      {/if}
      <button
        type="button"
        onclick={openEmailModal}
        class="inline-flex items-center gap-2 px-4 py-2 bg-bright-purple text-white rounded-[10px] hover:bg-bright-purple/90 transition-colors duration-150"
      >
        <Mail class="w-4 h-4" />
        Email Invoice
      </button>
      <a
        href="/{workspaceId}/invoices/{invoice.hashid}/pdf"
        target="_blank"
        class="inline-flex items-center gap-2 px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
      >
        <Download class="w-4 h-4" />
        Download PDF
      </a>
      <Link
        href="/{workspaceId}/invoices"
        class="inline-flex items-center gap-2 px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
      >
        <ArrowLeft class="w-4 h-4" />
        Back
      </Link>
    </div>
  {/snippet}

  <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
    <div
      class="p-4 border-b border-bg-tertiary flex items-start justify-between gap-4"
    >
      <div class="min-w-0">
        <div class="flex items-center gap-2">
          <h3 class="font-semibold text-lg truncate">{invoice.client.name}</h3>
          <span
            class="px-2 py-0.5 text-xs rounded-full capitalize {getStatusClasses(
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
            >Issued: {invoice.issued_on
              ? formatDate(invoice.issued_on)
              : "Not issued"}</span
          >
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
          <div class="mt-1 text-sm text-fg-muted whitespace-pre-line">
            {invoice.client.billing_address}
          </div>
        {:else}
          <div class="mt-1 text-sm text-fg-dim italic">No billing address</div>
        {/if}
      </div>

      <div class="bg-bg-primary border border-bg-tertiary rounded-[10px] p-4">
        <div class="text-sm text-fg-muted mb-2">Line Items</div>
        <div class="text-sm text-fg-muted">
          {invoice.lines.length} item{invoice.lines.length === 1 ? "" : "s"}
        </div>
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
                  <span class="text-fg-primary"
                    >{line.description || "No description"}</span
                  >
                </td>
                <td class="py-3 text-right font-tabular"
                  >{Number(line.qty_hours).toFixed(2)}</td
                >
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

<Modal bind:open={emailModalOpen} title="Email Invoice" maxWidth="max-w-lg">
  <form
    onsubmit={(e) => {
      e.preventDefault();
      sendEmail();
    }}
    class="space-y-4"
  >
    <div>
      <label for="recipients" class="block text-sm font-medium mb-1"
        >Recipients</label
      >
      <input
        id="recipients"
        type="text"
        bind:value={emailRecipients}
        placeholder="email@example.com, another@example.com"
        class="w-full px-3 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] focus:outline-none focus:ring-2 focus:ring-bright-purple/50 focus:border-bright-purple"
        required
      />
      <p class="mt-1 text-xs text-fg-muted">
        Separate multiple emails with commas
      </p>
    </div>

    <div>
      <label for="message" class="block text-sm font-medium mb-1"
        >Message (optional)</label
      >
      <textarea
        id="message"
        bind:value={emailMessage}
        rows={4}
        placeholder="Add a personal message to include in the email..."
        class="w-full px-3 py-2 bg-bg-primary border border-bg-tertiary rounded-[10px] focus:outline-none focus:ring-2 focus:ring-bright-purple/50 focus:border-bright-purple resize-none"
      ></textarea>
    </div>

    <div class="flex items-center gap-2">
      <input
        id="cc_self"
        type="checkbox"
        bind:checked={ccSelf}
        class="w-4 h-4 rounded border-bg-tertiary text-bright-purple focus:ring-bright-purple/50"
      />
      <label for="cc_self" class="text-sm">CC myself ({userEmail})</label>
    </div>

    <div class="flex justify-end gap-2 pt-2">
      <button
        type="button"
        onclick={() => (emailModalOpen = false)}
        class="px-4 py-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
      >
        Cancel
      </button>
      <button
        type="submit"
        disabled={sending || !emailRecipients.trim()}
        class="px-4 py-2 bg-bright-purple text-white rounded-[10px] hover:bg-bright-purple/90 transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {sending ? "Sending..." : "Send Invoice"}
      </button>
    </div>
  </form>
</Modal>
