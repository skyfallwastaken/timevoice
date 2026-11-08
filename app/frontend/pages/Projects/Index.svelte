<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import ColorPicker from "../../components/ColorPicker.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import SelectInput from "../../components/SelectInput.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import { page } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import { createInlineCrud } from "../../lib/inline-crud.svelte";
  import { FolderKanban, Plus, Edit2, Trash2, Briefcase } from "@lucide/svelte";
  import type { Project, Client } from "../../types";

  let projects = $derived((page.props.projects as Project[]) || []);
  let clients = $derived((page.props.clients as Client[]) || []);
  let colors = $derived((page.props.colors as string[]) || []);

  type ProjectForm = {
    name: string;
    client_id: string;
    color: string;
    billable_default: boolean;
  };

  const crud = createInlineCrud<Project, ProjectForm>({
    key: "projects",
    routes: routes.projects,
    createDefaults: {
      name: "",
      client_id: "",
      color: (page.props.colors as string[])?.[0] ?? "",
      billable_default: true,
    },
    editDefaults: {
      name: "",
      client_id: "",
      color: "",
      billable_default: false,
    },
    toForm: (project) => ({
      name: project.name,
      client_id: project.client?.id?.toString() || "",
      color: project.color,
      billable_default: project.billable_default,
    }),
    toRecord: (form, project) => {
      const client = clients.find((c) => String(c.id) === form.client_id);
      return {
        ...project,
        name: form.name,
        color: form.color,
        billable_default: form.billable_default,
        client: client && { id: client.id, name: client.name },
      };
    },
    onCreated: () => (crud.createForm.color = colors[0] ?? ""),
  });
  const { createForm, editForm } = crud;
</script>

<PageLayout title="Projects" icon={FolderKanban} iconColor="text-bright-green">
  <SectionCard
    title="Create New Project"
    icon={Plus}
    iconColor="text-bright-green"
    bodyClass="p-4"
  >
    <div class="space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <FormField
          id="project-name"
          label="Project Name"
          error={createForm.errors.name}
        >
          {#snippet children({ describedBy })}
            <TextInput
              id="project-name"
              tone="green"
              bind:value={createForm.name}
              placeholder="Enter project name..."
              onkeydown={(e) =>
                e.key === "Enter" && createForm.name && crud.create()}
              aria-describedby={describedBy}
            />
          {/snippet}
        </FormField>
        <FormField id="project-client" label="Client">
          {#snippet children({ describedBy })}
            <SelectInput
              id="project-client"
              tone="green"
              bind:value={createForm.client_id}
              aria-describedby={describedBy}
            >
              <option value="">No Client</option>
              {#each clients as client}
                <option value={client.id.toString()}>{client.name}</option>
              {/each}
            </SelectInput>
          {/snippet}
        </FormField>
      </div>

      <ColorPicker {colors} bind:value={createForm.color} />

      <div class="flex items-center justify-between">
        <label class="flex items-center gap-2 cursor-pointer">
          <Checkbox bind:checked={createForm.billable_default} />
          <span class="text-sm text-fg-secondary">Billable by default</span>
        </label>

        <Button
          tone="green"
          onclick={crud.create}
          disabled={createForm.processing || !createForm.name}
        >
          <Plus class="w-4 h-4" />
          Create Project
        </Button>
      </div>
    </div>
  </SectionCard>

  <SectionCard title={`All Projects (${projects.length})`}>
    {#if projects.length === 0}
      <EmptyState
        icon={Briefcase}
        title="No projects yet"
        description="Create your first project with the form above."
      />
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each projects as project, i}
          {@const isLast = i === projects.length - 1}
          {#if crud.editingId === project.id}
            <div class="p-4 {isLast ? 'rounded-b-[10px]' : ''} space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  id="edit-project-name-{project.id}"
                  label="Project Name"
                  error={editForm.errors.name}
                >
                  {#snippet children({ describedBy })}
                    <TextInput
                      id="edit-project-name-{project.id}"
                      tone="green"
                      autofocus
                      onkeydown={(e) => crud.editKeydown(e, project.id)}
                      bind:value={editForm.name}
                      aria-describedby={describedBy}
                    />
                  {/snippet}
                </FormField>
                <FormField id="edit-project-client-{project.id}" label="Client">
                  {#snippet children({ describedBy })}
                    <SelectInput
                      id="edit-project-client-{project.id}"
                      tone="green"
                      bind:value={editForm.client_id}
                      onkeydown={(e) => crud.editKeydown(e, project.id)}
                      aria-describedby={describedBy}
                    >
                      <option value="">No Client</option>
                      {#each clients as client}
                        <option value={client.id.toString()}
                          >{client.name}</option
                        >
                      {/each}
                    </SelectInput>
                  {/snippet}
                </FormField>
              </div>

              <ColorPicker {colors} bind:value={editForm.color} />

              <div class="flex items-center justify-between">
                <label class="flex items-center gap-2 cursor-pointer">
                  <Checkbox bind:checked={editForm.billable_default} />
                  <span class="text-sm text-fg-secondary"
                    >Billable by default</span
                  >
                </label>

                <div class="flex items-center gap-2">
                  <Button variant="ghost" onclick={crud.cancelEditing}>
                    Cancel
                  </Button>
                  <Button
                    tone="green"
                    onclick={() => crud.update(project.id)}
                    disabled={editForm.processing}
                  >
                    Save
                  </Button>
                </div>
              </div>
            </div>
          {:else}
            <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
              {#snippet leading()}
                <span
                  class="block w-4 h-4 rounded-full"
                  style="background-color: {project.color}"
                ></span>
              {/snippet}
              {#snippet primary()}
                <span class="flex items-center gap-2">
                  {project.name}
                  {#if project.billable_default}
                    <span
                      class="px-2 py-0.5 text-xs font-medium bg-bright-green/20 text-bright-green rounded-full"
                      >Billable</span
                    >
                  {/if}
                </span>
              {/snippet}
              {#snippet secondary()}
                {#if project.client}
                  {project.client.name}
                {:else}
                  <span class="text-fg-muted italic">No client</span>
                {/if}
              {/snippet}
              {#snippet actions()}
                <IconButton
                  aria-label="Edit project"
                  disabled={project.id < 0}
                  onclick={() => crud.startEditing(project)}
                >
                  <Edit2 class="w-4 h-4" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete project"
                  disabled={project.id < 0}
                  onclick={() => (crud.toDelete = project)}
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
    open={crud.toDelete !== null}
    title="Delete Project"
    itemName={crud.toDelete?.name || "this project"}
    warningMessage="This action cannot be undone. This will remove the project association from all time entries."
    onConfirm={crud.confirmDelete}
    onClose={() => (crud.toDelete = null)}
  />
</PageLayout>
