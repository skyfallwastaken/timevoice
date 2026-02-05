<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import TextArea from "../../components/TextArea.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import { page } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import {
    Users,
    Plus,
    Edit2,
    Trash2,
    Check,
    X,
    Building2,
  } from "lucide-svelte";
  import type { Client } from "../../types";

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  let clients = $derived(($page.props.clients as Client[]) || []);

  let editingId: number | null = $state(null);

  let createForm = useForm({
    name: "",
    billing_address: "",
  });

  let editForm = useForm({
    name: "",
    billing_address: "",
  });

  function startEditing(client: Client) {
    editingId = client.id;
    $editForm.name = client.name;
    $editForm.billing_address = client.billing_address || "";
  }

  function cancelEditing() {
    editingId = null;
    $editForm.reset();
  }

  function handleCreate() {
    if (!workspaceId) return;
    $createForm.post(routes.clients.create(workspaceId), {
      onSuccess: () => {
        $createForm.reset();
      },
    });
  }

  function handleUpdate(clientId: number) {
    if (!workspaceId) return;
    $editForm.patch(routes.clients.update(workspaceId, clientId), {
      onSuccess: () => {
        editingId = null;
        $editForm.reset();
      },
    });
  }

  let clientToDelete: Client | null = $state(null);

  function confirmDelete() {
    if (clientToDelete && workspaceId) {
      $editForm.delete(routes.clients.delete(workspaceId, clientToDelete.id));
    }
    clientToDelete = null;
  }
</script>

<PageLayout
  title="Clients"
  icon={Users}
  iconColor="text-bright-blue"
  variant="narrow"
  flash={$page.props.flash}
>
  <SectionCard title="Create New Client" icon={Plus} iconColor="text-bright-blue" bodyClass="p-4">
    <form
      class="space-y-4"
      onsubmit={(e) => {
        e.preventDefault();
        if ($createForm.name) handleCreate();
      }}
    >
      <FormField id="client-name" label="Client Name">
        {#snippet children({ describedBy })}
          <TextInput
            id="client-name"
            tone="blue"
            bind:value={$createForm.name}
            placeholder="Enter client name..."
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <FormField
        id="billing-address"
        label="Billing Address"
        description="Line breaks will appear on invoices. Press Enter to create."
      >
        {#snippet children({ describedBy })}
          <TextArea
            id="billing-address"
            tone="blue"
            bind:value={$createForm.billing_address}
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
          disabled={$createForm.processing || !$createForm.name}
        >
          <Plus class="w-4 h-4" />
          Create Client
        </Button>
      </div>
    </form>
  </SectionCard>

  <SectionCard title={`All Clients (${clients.length})`}>
    {#if clients.length === 0}
      <div class="p-8 text-center text-fg-muted">
        <Building2 class="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>No clients yet. Create your first client above!</p>
      </div>
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each clients as client, i}
          {@const isLast = i === clients.length - 1}
          {#if editingId === client.id}
            <div class="p-4 {isLast ? 'rounded-b-[10px]' : ''} space-y-4">
              <FormField id="edit-name-{client.id}" label="Client Name">
                {#snippet children({ describedBy })}
                  <TextInput
                    id="edit-name-{client.id}"
                    tone="blue"
                    bind:value={$editForm.name}
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>

              <FormField id="edit-address-{client.id}" label="Billing Address">
                {#snippet children({ describedBy })}
                  <TextArea
                    id="edit-address-{client.id}"
                    tone="blue"
                    bind:value={$editForm.billing_address}
                    rows={3}
                    aria-describedby={describedBy}
                  />
                {/snippet}
              </FormField>

              <div class="flex justify-end">
                <div class="flex items-center gap-2">
                  <IconButton
                    aria-label="Cancel editing"
                    onclick={cancelEditing}
                  >
                    <X class="w-5 h-5" />
                  </IconButton>
                  <IconButton
                    tone="primary"
                    aria-label="Save changes"
                    onclick={() => handleUpdate(client.id)}
                    disabled={$editForm.processing}
                  >
                    <Check class="w-5 h-5" />
                  </IconButton>
                </div>
              </div>
            </div>
          {:else}
            <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
              {#snippet primary()}
                {client.name}
              {/snippet}
              {#snippet secondary()}
                {#if client.billing_address}
                  <span class="whitespace-pre-line">
                    {client.billing_address}
                  </span>
                {:else}
                  <span class="text-fg-dim italic">No billing address</span>
                {/if}
              {/snippet}
              {#snippet actions()}
                <IconButton
                  aria-label="Edit client"
                  onclick={() => startEditing(client)}
                >
                  <Edit2 class="w-4 h-4" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete client"
                  onclick={() => (clientToDelete = client)}
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
    open={!!clientToDelete}
    title="Delete Client"
    itemName={clientToDelete?.name || "this client"}
    warningMessage="This action cannot be undone. This will remove the client association from all projects."
    onConfirm={confirmDelete}
    onClose={() => (clientToDelete = null)}
  />
</PageLayout>
