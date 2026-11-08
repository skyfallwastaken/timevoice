<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import TextArea from "../../components/TextArea.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import { page } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import { createInlineCrud } from "../../lib/inline-crud.svelte";
  import { Users, Plus, Edit2, Trash2, Building2 } from "@lucide/svelte";
  import type { Client } from "../../types";

  let clients = $derived((page.props.clients as Client[]) || []);

  const blankClient = { name: "", email: "", billing_address: "" };
  const crud = createInlineCrud<Client, typeof blankClient>({
    key: "clients",
    routes: routes.clients,
    createDefaults: blankClient,
    editDefaults: blankClient,
    toForm: (client) => ({
      name: client.name,
      email: client.email || "",
      billing_address: client.billing_address || "",
    }),
    toRecord: (form, client) => ({ ...client, ...form }),
  });
  const { createForm, editForm } = crud;
</script>

<PageLayout title="Clients" icon={Users} iconColor="text-bright-blue">
  <SectionCard
    title="Create New Client"
    icon={Plus}
    iconColor="text-bright-blue"
    bodyClass="p-4"
  >
    <form
      class="space-y-4"
      onsubmit={(e) => {
        e.preventDefault();
        if (createForm.name) crud.create();
      }}
    >
      <FormField
        id="client-name"
        label="Client Name"
        error={createForm.errors.name}
      >
        {#snippet children({ describedBy })}
          <TextInput
            id="client-name"
            tone="blue"
            bind:value={createForm.name}
            placeholder="Enter client name..."
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <FormField
        id="client-email"
        label="Email"
        description="Invoices are emailed here by default. Separate multiple emails with commas."
        error={createForm.errors.email}
      >
        {#snippet children({ describedBy })}
          <TextInput
            id="client-email"
            tone="blue"
            bind:value={createForm.email}
            placeholder="billing@example.com"
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <FormField
        id="billing-address"
        label="Billing Address"
        description="Line breaks will appear on invoices."
      >
        {#snippet children({ describedBy })}
          <TextArea
            id="billing-address"
            tone="blue"
            bind:value={createForm.billing_address}
            rows={3}
            placeholder="Street address
City, State ZIP
Country"
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <div class="flex justify-end">
        <Button
          type="submit"
          tone="blue"
          disabled={createForm.processing || !createForm.name}
        >
          <Plus class="w-4 h-4" />
          Create Client
        </Button>
      </div>
    </form>
  </SectionCard>

  <SectionCard title={`All Clients (${clients.length})`}>
    {#if clients.length === 0}
      <EmptyState
        icon={Building2}
        title="No clients yet"
        description="Create your first client with the form above."
      />
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each clients as client, i}
          {@const isLast = i === clients.length - 1}
          {#if crud.editingId === client.id}
            <div class="p-4 {isLast ? 'rounded-b-[10px]' : ''} space-y-4">
              <FormField
                id="edit-name-{client.id}"
                label="Client Name"
                error={editForm.errors.name}
              >
                {#snippet children({ describedBy })}
                  <TextInput
                    id="edit-name-{client.id}"
                    tone="blue"
                    autofocus
                    onkeydown={(e) => crud.editKeydown(e, client.id)}
                    bind:value={editForm.name}
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>

              <FormField
                id="edit-email-{client.id}"
                label="Email"
                description="Separate multiple emails with commas."
                error={editForm.errors.email}
              >
                {#snippet children({ describedBy })}
                  <TextInput
                    id="edit-email-{client.id}"
                    tone="blue"
                    bind:value={editForm.email}
                    onkeydown={(e) => crud.editKeydown(e, client.id)}
                    placeholder="billing@example.com"
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>

              <FormField id="edit-address-{client.id}" label="Billing Address">
                {#snippet children({ describedBy })}
                  <TextArea
                    id="edit-address-{client.id}"
                    tone="blue"
                    bind:value={editForm.billing_address}
                    onkeydown={(e) => crud.editKeydown(e, client.id)}
                    rows={3}
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>

              <div class="flex justify-end gap-2">
                <Button variant="ghost" onclick={crud.cancelEditing}>
                  Cancel
                </Button>
                <Button
                  tone="blue"
                  onclick={() => crud.update(client.id)}
                  disabled={editForm.processing}
                >
                  Save
                </Button>
              </div>
            </div>
          {:else}
            <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
              {#snippet primary()}
                {client.name}
              {/snippet}
              {#snippet secondary()}
                {#if client.email}
                  <span class="block truncate">{client.email}</span>
                {/if}
                {#if client.billing_address}
                  <span class="whitespace-pre-line">
                    {client.billing_address}
                  </span>
                {:else}
                  <span class="text-fg-muted italic">No billing address</span>
                {/if}
              {/snippet}
              {#snippet actions()}
                <IconButton
                  aria-label="Edit client"
                  disabled={client.id < 0}
                  onclick={() => crud.startEditing(client)}
                >
                  <Edit2 class="w-4 h-4" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete client"
                  disabled={client.id < 0}
                  onclick={() => (crud.toDelete = client)}
                >
                  <Trash2 class="w-4 h-4" />
                </IconButton>
              {/snippet}
            </ListRow>
          {/if}
        {/each}
      </div>
    {/if}
  </SectionCard>

  <ConfirmDeleteModal
    open={!!crud.toDelete}
    title="Delete Client"
    itemName={crud.toDelete?.name || "this client"}
    warningMessage="This action cannot be undone. This will remove the client association from all projects."
    onConfirm={crud.confirmDelete}
    onClose={() => (crud.toDelete = null)}
  />
</PageLayout>
