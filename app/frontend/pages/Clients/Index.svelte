<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import PageLayout from '../../components/PageLayout.svelte'
  import { page } from '@inertiajs/svelte'
  import { useForm } from '@inertiajs/svelte'
  import { Users, Plus, Edit2, Trash2, Check, X, Building2 } from 'lucide-svelte'

  const workspaceId = $derived($page.props.auth?.workspace?.id)

  type Client = {
    id: number
    name: string
    billing_address: string | null
  }

  let clients = $derived($page.props.clients as Client[] || [])

  let editingId: number | null = $state(null)

  // Create form
  let createForm = useForm({
    name: '',
    billing_address: ''
  })

  // Edit form
  let editForm = useForm({
    name: '',
    billing_address: ''
  })

  function startEditing(client: Client) {
    editingId = client.id
    $editForm.name = client.name
    $editForm.billing_address = client.billing_address || ''
  }

  function cancelEditing() {
    editingId = null
    $editForm.reset()
  }

  function handleCreate() {
    $createForm.post(`/${workspaceId}/clients`, {
      onSuccess: () => {
        $createForm.reset()
      }
    })
  }

  function handleUpdate(clientId: number) {
    $editForm.patch(`/${workspaceId}/clients/${clientId}`, {
      onSuccess: () => {
        editingId = null
        $editForm.reset()
      }
    })
  }

  function handleDelete(clientId: number) {
    if (confirm('Are you sure you want to delete this client? This will remove the client association from all projects.')) {
      $editForm.delete(`/${workspaceId}/clients/${clientId}`)
    }
  }
</script>

<AppShell>
  <PageLayout title="Clients" icon={Users} iconColor="text-bright-blue" variant="narrow" flash={$page.props.flash}>
    <!-- Create New Client -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <div class="flex items-center gap-2">
          <Plus class="w-5 h-5 text-bright-blue" />
          <h3 class="font-semibold">Create New Client</h3>
        </div>
      </div>
      <div class="p-4 space-y-4">
        <div>
          <label for="client-name" class="block text-sm font-medium text-fg-secondary mb-1">Client Name</label>
          <input
            id="client-name"
            type="text"
            bind:value={$createForm.name}
            placeholder="Enter client name..."
            class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue transition-colors duration-150"
          />
        </div>

        <div>
          <label for="billing-address" class="block text-sm font-medium text-fg-secondary mb-1">Billing Address</label>
          <textarea
            id="billing-address"
            bind:value={$createForm.billing_address}
            rows="3"
            placeholder="Street address
City, State ZIP
Country"
            class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue transition-colors duration-150 resize-none"
          ></textarea>
          <p class="text-xs text-fg-muted mt-1">Line breaks will appear on invoices.</p>
        </div>

        <div class="flex justify-end">
          <button
            onclick={handleCreate}
            disabled={$createForm.processing || !$createForm.name}
            class="flex items-center gap-2 px-4 py-2 bg-bright-blue hover:bg-accent-blue text-bg-primary rounded-[10px] font-medium transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Plus class="w-4 h-4" />
            Create Client
          </button>
        </div>
      </div>
    </div>

    <!-- Clients List -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">All Clients ({clients.length})</h3>
      </div>

      {#if clients.length === 0}
        <div class="p-8 text-center text-fg-muted">
          <Building2 class="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No clients yet. Create your first client above!</p>
        </div>
      {:else}
        <div class="divide-y divide-bg-tertiary">
          {#each clients as client}
            <div class="p-4">
              {#if editingId === client.id}
                <!-- Edit Mode -->
                <div class="space-y-4">
                  <div>
                    <label for="edit-name-{client.id}" class="block text-sm font-medium text-fg-secondary mb-1">Client Name</label>
                    <input
                      id="edit-name-{client.id}"
                      type="text"
                      bind:value={$editForm.name}
                      class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
                    />
                  </div>

                  <div>
                    <label for="edit-address-{client.id}" class="block text-sm font-medium text-fg-secondary mb-1">Billing Address</label>
                    <textarea
                      id="edit-address-{client.id}"
                      bind:value={$editForm.billing_address}
                      rows="3"
                      class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150 resize-none"
                    ></textarea>
                  </div>

                  <div class="flex justify-end">
                    <div class="flex items-center gap-2">
                      <button
                        onclick={cancelEditing}
                        class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                        aria-label="Cancel editing"
                      >
                        <X class="w-5 h-5" />
                      </button>
                      <button
                        onclick={() => handleUpdate(client.id)}
                        disabled={$editForm.processing}
                        class="p-2 text-bright-blue hover:text-accent-blue transition-colors duration-150"
                        aria-label="Save changes"
                      >
                        <Check class="w-5 h-5" />
                      </button>
                    </div>
                  </div>
                </div>
              {:else}
                <!-- View Mode -->
                <div class="flex items-center justify-between">
                  <div>
                    <p class="font-medium">{client.name}</p>
                    {#if client.billing_address}
                      <p class="text-sm text-fg-muted whitespace-pre-line">{client.billing_address}</p>
                    {:else}
                      <p class="text-sm text-fg-dim italic">No billing address</p>
                    {/if}
                  </div>

                  <div class="flex items-center gap-2">
                    <button
                      onclick={() => startEditing(client)}
                      class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                      aria-label="Edit client"
                    >
                      <Edit2 class="w-4 h-4" />
                    </button>
                    <button
                      onclick={() => handleDelete(client.id)}
                      class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                      aria-label="Delete client"
                    >
                      <Trash2 class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
    </div>
  </PageLayout>
</AppShell>
