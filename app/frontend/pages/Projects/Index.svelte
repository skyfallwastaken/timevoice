<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import PageLayout from '../../components/PageLayout.svelte'
  import { page } from '@inertiajs/svelte'
  import { useForm } from '@inertiajs/svelte'
  import { FolderKanban, Plus, Edit2, Trash2, Check, X, Briefcase } from 'lucide-svelte'

  const workspaceId = $derived($page.props.auth?.workspace?.hashid)

  type Project = {
    id: number
    name: string
    color: string
    billable_default: boolean
    client?: {
      id: number
      name: string
    }
  }

  type Client = {
    id: number
    name: string
  }

  let projects = $derived($page.props.projects as Project[] || [])
  let clients = $derived($page.props.clients as Client[] || [])
  let colors = $derived($page.props.colors as string[] || [])

  let editingId: number | null = $state(null)

  // Create form - initialize with empty values
  let createForm = useForm({
    name: '',
    client_id: '',
    color: '',
    billable_default: false
  })

  // Set default color when colors become available
  $effect(() => {
    if (colors.length > 0 && !$createForm.color) {
      $createForm.color = colors[0]
    }
  })

  // Edit form (dynamically updated)
  let editForm = useForm({
    name: '',
    client_id: '',
    color: '',
    billable_default: false
  })

  function startEditing(project: Project) {
    editingId = project.id
    $editForm.name = project.name
    $editForm.client_id = project.client?.id?.toString() || ''
    $editForm.color = project.color
    $editForm.billable_default = project.billable_default
  }

  function cancelEditing() {
    editingId = null
    $editForm.reset()
  }

  function handleCreate() {
    $createForm.post(`/${workspaceId}/projects`, {
      onSuccess: () => {
        $createForm.reset()
        // Reset color to default
        if (colors.length > 0) {
          $createForm.color = colors[0]
        }
      }
    })
  }

  function handleUpdate(projectId: number) {
    $editForm.patch(`/${workspaceId}/projects/${projectId}`, {
      onSuccess: () => {
        editingId = null
        $editForm.reset()
      }
    })
  }

  function handleDelete(projectId: number) {
    if (confirm('Are you sure you want to delete this project? This will remove the project association from all time entries.')) {
      $editForm.delete(`/${workspaceId}/projects/${projectId}`)
    }
  }
</script>

<AppShell>
  <PageLayout title="Projects" icon={FolderKanban} iconColor="text-bright-green" variant="narrow" flash={$page.props.flash}>
    <!-- Create New Project -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <div class="flex items-center gap-2">
          <Plus class="w-5 h-5 text-bright-green" />
          <h3 class="font-semibold">Create New Project</h3>
        </div>
      </div>
      <div class="p-4 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label for="project-name" class="block text-sm font-medium text-fg-secondary mb-1">Project Name</label>
            <input
              id="project-name"
              type="text"
              bind:value={$createForm.name}
              placeholder="Enter project name..."
              class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-green transition-colors duration-150"
            />
          </div>
          <div>
            <label for="project-client" class="block text-sm font-medium text-fg-secondary mb-1">Client</label>
            <select
              id="project-client"
              bind:value={$createForm.client_id}
              class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-green transition-colors duration-150"
            >
              <option value="">No Client</option>
              {#each clients as client}
                <option value={client.id}>{client.name}</option>
              {/each}
            </select>
          </div>
        </div>

        <div>
          <span class="block text-sm font-medium text-fg-secondary mb-2">Color</span>
          <div class="flex flex-wrap gap-2">
            {#each colors as color}
                <button
                  type="button"
                  onclick={() => $createForm.color = color}
                  class="w-8 h-8 rounded-full border-2 transition-all duration-150 {$createForm.color === color ? 'border-fg-primary scale-110' : 'border-transparent hover:scale-105'}"
                  style="background-color: {color}"
                  aria-label="Select color {color}"
                ></button>
            {/each}
          </div>
        </div>

        <div class="flex items-center justify-between">
          <label class="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              bind:checked={$createForm.billable_default}
              class="w-4 h-4 rounded border-bg-tertiary bg-bg-primary text-bright-green focus:ring-bright-green"
            />
            <span class="text-sm text-fg-secondary">Billable by default</span>
          </label>

          <button
            onclick={handleCreate}
            disabled={$createForm.processing || !$createForm.name}
            class="flex items-center gap-2 px-4 py-2 bg-bright-green hover:bg-accent-green text-bg-primary rounded-[10px] font-medium transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Plus class="w-4 h-4" />
            Create Project
          </button>
        </div>
      </div>
    </div>

    <!-- Projects List -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
      <div class="p-4 border-b border-bg-tertiary">
        <h3 class="font-semibold">All Projects ({projects.length})</h3>
      </div>

      {#if projects.length === 0}
        <div class="p-8 text-center text-fg-muted">
          <Briefcase class="w-12 h-12 mx-auto mb-4 opacity-50" />
          <p>No projects yet. Create your first project above!</p>
        </div>
      {:else}
        <div class="divide-y divide-bg-tertiary">
          {#each projects as project}
            <div class="p-4">
              {#if editingId === project.id}
                <!-- Edit Mode -->
                <div class="space-y-4">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                      <label for="edit-project-name-{project.id}" class="block text-sm font-medium text-fg-secondary mb-1">Project Name</label>
                      <input
                        id="edit-project-name-{project.id}"
                        type="text"
                        bind:value={$editForm.name}
                        class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-green transition-colors duration-150"
                      />
                    </div>
                    <div>
                      <label for="edit-project-client-{project.id}" class="block text-sm font-medium text-fg-secondary mb-1">Client</label>
                      <select
                        id="edit-project-client-{project.id}"
                        bind:value={$editForm.client_id}
                        class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-green transition-colors duration-150"
                      >
                        <option value="">No Client</option>
                        {#each clients as client}
                          <option value={client.id}>{client.name}</option>
                        {/each}
                      </select>
                    </div>
                  </div>

                  <div>
                    <span class="block text-sm font-medium text-fg-secondary mb-2">Color</span>
                    <div class="flex flex-wrap gap-2">
                      {#each colors as color}
                        <button
                          type="button"
                          onclick={() => $editForm.color = color}
                          class="w-8 h-8 rounded-full border-2 transition-all duration-150 {$editForm.color === color ? 'border-fg-primary scale-110' : 'border-transparent hover:scale-105'}"
                          style="background-color: {color}"
                          aria-label="Select color {color}"
                        ></button>
                      {/each}
                    </div>
                  </div>

                  <div class="flex items-center justify-between">
                    <label class="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        bind:checked={$editForm.billable_default}
                        class="w-4 h-4 rounded border-bg-tertiary bg-bg-primary text-bright-green focus:ring-bright-green"
                      />
                      <span class="text-sm text-fg-secondary">Billable by default</span>
                    </label>

                    <div class="flex items-center gap-2">
                      <button
                        onclick={cancelEditing}
                        class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                        aria-label="Cancel editing"
                      >
                        <X class="w-5 h-5" />
                      </button>
                      <button
                        onclick={() => handleUpdate(project.id)}
                        disabled={$editForm.processing}
                        class="p-2 text-bright-green hover:text-accent-green transition-colors duration-150"
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
                  <div class="flex items-center gap-3">
                    <span class="w-4 h-4 rounded-full" style="background-color: {project.color}"></span>
                    <div>
                      <p class="font-medium">{project.name}</p>
                      {#if project.client}
                        <p class="text-sm text-fg-muted">{project.client.name}</p>
                      {:else}
                        <p class="text-sm text-fg-dim italic">No client</p>
                      {/if}
                    </div>
                    {#if project.billable_default}
                      <span class="px-2 py-0.5 text-xs bg-bright-green/20 text-bright-green rounded-full">Billable</span>
                    {/if}
                  </div>

                  <div class="flex items-center gap-2">
                    <button
                      onclick={() => startEditing(project)}
                      class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
                      aria-label="Edit project"
                    >
                      <Edit2 class="w-4 h-4" />
                    </button>
                    <button
                      onclick={() => handleDelete(project.id)}
                      class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                      aria-label="Delete project"
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
