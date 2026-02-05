<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import ColorPicker from "../../components/ColorPicker.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import SelectInput from "../../components/SelectInput.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import { page } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import {
    FolderKanban,
    Plus,
    Edit2,
    Trash2,
    Check,
    X,
    Briefcase,
  } from "lucide-svelte";
  import type { Project, Client } from "../../types";

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  let projects = $derived(($page.props.projects as Project[]) || []);
  let clients = $derived(($page.props.clients as Client[]) || []);
  let colors = $derived(($page.props.colors as string[]) || []);

  let editingId: number | null = $state(null);

  let createForm = useForm({
    name: "",
    client_id: "",
    color: ($page.props.colors as string[])?.[0] ?? "",
    billable_default: false,
  });

  let editForm = useForm({
    name: "",
    client_id: "",
    color: "",
    billable_default: false,
  });

  function startEditing(project: Project) {
    editingId = project.id;
    $editForm.name = project.name;
    $editForm.client_id = project.client?.id?.toString() || "";
    $editForm.color = project.color;
    $editForm.billable_default = project.billable_default;
  }

  function cancelEditing() {
    editingId = null;
    $editForm.reset();
  }

  function handleCreate() {
    if (!workspaceId) return;
    $createForm.post(routes.projects.create(workspaceId), {
      onSuccess: () => {
        $createForm.reset();
        $createForm.color = colors[0] ?? "";
      },
    });
  }

  function handleUpdate(projectId: number) {
    if (!workspaceId) return;
    $editForm.patch(routes.projects.update(workspaceId, projectId), {
      onSuccess: () => {
        editingId = null;
        $editForm.reset();
      },
    });
  }

  let projectToDelete: Project | null = $state(null);

  function confirmDelete() {
    if (projectToDelete && workspaceId) {
      $editForm.delete(routes.projects.delete(workspaceId, projectToDelete.id));
    }
    projectToDelete = null;
  }
</script>

<PageLayout
  title="Projects"
  icon={FolderKanban}
  iconColor="text-bright-green"
  variant="narrow"
  flash={$page.props.flash}
>
  <SectionCard title="Create New Project" icon={Plus} iconColor="text-bright-green" bodyClass="p-4">
    <div class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <FormField id="project-name" label="Project Name">
          {#snippet children({ describedBy })}
            <TextInput
              id="project-name"
              tone="green"
              bind:value={$createForm.name}
              placeholder="Enter project name..."
              onkeydown={(e) =>
                e.key === "Enter" && $createForm.name && handleCreate()}
              aria-describedby={describedBy}
            />
          {/snippet}
        </FormField>
        <FormField id="project-client" label="Client">
          {#snippet children({ describedBy })}
            <SelectInput
              id="project-client"
              tone="green"
              bind:value={$createForm.client_id}
              aria-describedby={describedBy}
            >
              <option value="">No Client</option>
              {#each clients as client}
                <option value={client.id}>{client.name}</option>
              {/each}
            </SelectInput>
          {/snippet}
        </FormField>
      </div>

      <ColorPicker {colors} bind:value={$createForm.color} />

      <div class="flex items-center justify-between">
        <label class="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            bind:checked={$createForm.billable_default}
            class="w-4 h-4 rounded border-bg-tertiary bg-bg-primary text-bright-green focus:ring-bright-green"
          />
          <span class="text-sm text-fg-secondary">Billable by default</span>
        </label>

        <Button
          tone="green"
          onclick={handleCreate}
          disabled={$createForm.processing || !$createForm.name}
        >
          <Plus class="w-4 h-4" />
          Create Project
        </Button>
      </div>
    </div>
  </SectionCard>

  <SectionCard title={`All Projects (${projects.length})`}>
    {#if projects.length === 0}
      <div class="p-8 text-center text-fg-muted">
        <Briefcase class="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>No projects yet. Create your first project above!</p>
      </div>
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each projects as project, i}
          {@const isLast = i === projects.length - 1}
          {#if editingId === project.id}
            <div class="p-4 {isLast ? 'rounded-b-[10px]' : ''} space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  id="edit-project-name-{project.id}"
                  label="Project Name"
                >
                  {#snippet children({ describedBy })}
                    <TextInput
                      id="edit-project-name-{project.id}"
                      tone="green"
                      bind:value={$editForm.name}
                      aria-describedby={describedBy}
                    />
                  {/snippet}
                </FormField>
                <FormField
                  id="edit-project-client-{project.id}"
                  label="Client"
                >
                  {#snippet children({ describedBy })}
                    <SelectInput
                      id="edit-project-client-{project.id}"
                      tone="green"
                      bind:value={$editForm.client_id}
                      aria-describedby={describedBy}
                    >
                      <option value="">No Client</option>
                      {#each clients as client}
                        <option value={client.id}>{client.name}</option>
                      {/each}
                    </SelectInput>
                  {/snippet}
                </FormField>
              </div>

              <ColorPicker {colors} bind:value={$editForm.color} />

              <div class="flex items-center justify-between">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    bind:checked={$editForm.billable_default}
                    class="w-4 h-4 rounded border-bg-tertiary bg-bg-primary text-bright-green focus:ring-bright-green"
                  />
                  <span class="text-sm text-fg-secondary"
                    >Billable by default</span
                  >
                </label>

                <div class="flex items-center gap-2">
                  <IconButton
                    aria-label="Cancel editing"
                    onclick={cancelEditing}
                  >
                    <X class="w-5 h-5" />
                  </IconButton>
                  <IconButton
                    tone="success"
                    aria-label="Save changes"
                    onclick={() => handleUpdate(project.id)}
                    disabled={$editForm.processing}
                  >
                    <Check class="w-5 h-5" />
                  </IconButton>
                </div>
              </div>
            </div>
          {:else}
            <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
              {#snippet leading()}
                <span
                  class="w-4 h-4 rounded-full"
                  style="background-color: {project.color}"
                ></span>
              {/snippet}
              {#snippet primary()}
                <span class="flex items-center gap-2">
                  {project.name}
                  {#if project.billable_default}
                    <span
                      class="px-2 py-0.5 text-xs bg-bright-green/20 text-bright-green rounded-full"
                      >Billable</span
                    >
                  {/if}
                </span>
              {/snippet}
              {#snippet secondary()}
                {#if project.client}
                  {project.client.name}
                {:else}
                  <span class="text-fg-dim italic">No client</span>
                {/if}
              {/snippet}
              {#snippet actions()}
                <IconButton
                  aria-label="Edit project"
                  onclick={() => startEditing(project)}
                >
                  <Edit2 class="w-4 h-4" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete project"
                  onclick={() => (projectToDelete = project)}
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
    open={projectToDelete !== null}
    title="Delete Project"
    itemName={projectToDelete?.name || "this project"}
    warningMessage="This action cannot be undone. This will remove the project association from all time entries."
    onConfirm={confirmDelete}
    onClose={() => (projectToDelete = null)}
  />
</PageLayout>
