<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import PageLayout from '../../components/PageLayout.svelte'
  import { page } from '@inertiajs/svelte'
  import { useForm } from '@inertiajs/svelte'
  import { Tag, Plus, Edit2, Trash2, Check, X, Hash } from 'lucide-svelte'

  type TagItem = {
    id: number
    name: string
  }

  let tags = $derived($page.props.tags as TagItem[] || [])

  let editingId: number | null = $state(null)

  // Create form
  let createForm = useForm({
    name: ''
  })

  // Edit form
  let editForm = useForm({
    name: ''
  })

  function startEditing(tagItem: TagItem) {
    editingId = tagItem.id
    $editForm.name = tagItem.name
  }

  function cancelEditing() {
    editingId = null
    $editForm.reset()
  }

  function handleCreate() {
    $createForm.post('/tags', {
      onSuccess: () => {
        $createForm.reset()
      }
    })
  }

  function handleUpdate(tagId: number) {
    $editForm.patch(`/tags/${tagId}`, {
      onSuccess: () => {
        editingId = null
        $editForm.reset()
      }
    })
  }

  function handleDelete(tagId: number) {
    if (confirm('Are you sure you want to delete this tag? This will remove the tag from all time entries.')) {
      $editForm.delete(`/tags/${tagId}`)
    }
  }
</script>

<AppShell>
  <PageLayout title="Tags" icon={Tag} iconColor="text-bright-yellow" variant="narrow" flash={$page.props.flash}>
    <!-- Create New Tag -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <div class="flex items-center gap-2">
          <Plus class="w-5 h-5 text-bright-yellow" />
          <h3 class="font-semibold">Create New Tag</h3>
        </div>
      </div>
      <div class="p-4 space-y-4">
        <div>
          <label for="tag-name" class="block text-sm font-medium text-fg-secondary mb-1">Tag Name</label>
          <input
            id="tag-name"
            type="text"
            bind:value={$createForm.name}
            placeholder="Enter tag name..."
            class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-yellow transition-colors duration-150"
          />
        </div>

        <div class="flex justify-end">
          <button
            onclick={handleCreate}
            disabled={$createForm.processing || !$createForm.name}
            class="flex items-center gap-2 px-4 py-2 bg-bright-yellow hover:bg-accent-yellow text-bg-primary rounded-[10px] font-medium transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Plus class="w-4 h-4" />
            Create Tag
          </button>
        </div>
      </div>
    </div>

    <!-- Tags List -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">All Tags ({tags.length})</h3>
      </div>

      {#if tags.length === 0}
        <div class="p-8 text-center text-fg-muted">
          <Hash class="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No tags yet. Create your first tag above!</p>
        </div>
      {:else}
        <div class="divide-y divide-bg-tertiary">
          {#each tags as tagItem}
            <div class="p-4">
              {#if editingId === tagItem.id}
                <!-- Edit Mode -->
                <div class="flex items-center gap-4">
                  <div class="flex-1">
                    <label for="edit-tag-{tagItem.id}" class="block text-sm font-medium text-fg-secondary mb-1 sr-only">Tag Name</label>
                    <input
                      id="edit-tag-{tagItem.id}"
                      type="text"
                      bind:value={$editForm.name}
                      class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-yellow transition-colors duration-150"
                    />
                  </div>

                  <div class="flex items-center gap-2">
                    <button
                      onclick={cancelEditing}
                      class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                      aria-label="Cancel editing"
                    >
                      <X class="w-5 h-5" />
                    </button>
                    <button
                      onclick={() => handleUpdate(tagItem.id)}
                      disabled={$editForm.processing}
                      class="p-2 text-bright-yellow hover:text-accent-yellow transition-colors duration-150"
                      aria-label="Save changes"
                    >
                      <Check class="w-5 h-5" />
                    </button>
                  </div>
                </div>
              {:else}
                <!-- View Mode -->
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <Hash class="w-4 h-4 text-fg-muted" />
                    <span class="font-medium">{tagItem.name}</span>
                  </div>

                  <div class="flex items-center gap-2">
                    <button
                      onclick={() => startEditing(tagItem)}
                      class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                      aria-label="Edit tag"
                    >
                      <Edit2 class="w-4 h-4" />
                    </button>
                    <button
                      onclick={() => handleDelete(tagItem.id)}
                      class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                      aria-label="Delete tag"
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
