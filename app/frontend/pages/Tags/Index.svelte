<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import { page } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import { createInlineCrud } from "../../lib/inline-crud.svelte";
  import { Tag, Plus, Edit2, Trash2, Hash } from "@lucide/svelte";
  import type { Tag as TagType } from "../../types";

  let tags = $derived((page.props.tags as TagType[]) || []);

  const crud = createInlineCrud<TagType, { name: string }>({
    key: "tags",
    routes: routes.tags,
    createDefaults: { name: "" },
    editDefaults: { name: "" },
    toForm: (tagItem) => ({ name: tagItem.name }),
    toRecord: (form, tagItem) => ({ ...tagItem, name: form.name }),
  });
  const { createForm, editForm } = crud;
</script>

<PageLayout title="Tags" icon={Tag} iconColor="text-bright-yellow">
  <SectionCard
    title="Create New Tag"
    icon={Plus}
    iconColor="text-bright-yellow"
    bodyClass="p-4"
  >
    <div class="space-y-4">
      <FormField id="tag-name" label="Tag Name" error={createForm.errors.name}>
        {#snippet children({ describedBy })}
          <TextInput
            id="tag-name"
            tone="yellow"
            bind:value={createForm.name}
            placeholder="Enter tag name..."
            onkeydown={(e) =>
              e.key === "Enter" &&
              !e.isComposing &&
              createForm.name &&
              crud.create()}
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <div class="flex justify-end">
        <Button
          tone="yellow"
          onclick={crud.create}
          disabled={createForm.processing || !createForm.name}
        >
          <Plus class="w-4 h-4" />
          Create Tag
        </Button>
      </div>
    </div>
  </SectionCard>

  <SectionCard title={`All Tags (${tags.length})`}>
    {#if tags.length === 0}
      <EmptyState
        icon={Hash}
        title="No tags yet"
        description="Create your first tag with the form above."
      />
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each tags as tagItem, i}
          {@const isLast = i === tags.length - 1}
          {#if crud.editingId === tagItem.id}
            <!-- Keys bubble up from the row's fields: Enter saves, Escape cancels. -->
            <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
            <div
              class="p-4 {isLast
                ? 'rounded-b-[10px]'
                : ''} flex items-start gap-2"
              role="group"
              aria-label="Edit tag"
              onkeydown={(e) => crud.editKeydown(e, tagItem.id)}
            >
              <div class="flex-1">
                <FormField
                  id="edit-tag-{tagItem.id}"
                  label="Tag Name"
                  srOnly
                  error={editForm.errors.name}
                >
                  {#snippet children({ describedBy })}
                    <TextInput
                      id="edit-tag-{tagItem.id}"
                      tone="yellow"
                      bind:value={editForm.name}
                      autofocus
                      aria-describedby={describedBy}
                    />
                  {/snippet}
                </FormField>
              </div>

              <Button variant="ghost" onclick={crud.cancelEditing}
                >Cancel</Button
              >
              <Button
                tone="yellow"
                onclick={() => crud.update(tagItem.id)}
                disabled={editForm.processing}
              >
                Save
              </Button>
            </div>
          {:else}
            <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
              {#snippet leading()}
                <Hash class="w-4 h-4 text-fg-muted" />
              {/snippet}
              {#snippet primary()}
                {tagItem.name}
              {/snippet}
              {#snippet actions()}
                <IconButton
                  aria-label="Edit tag"
                  data-edit-id={tagItem.id}
                  disabled={tagItem.id < 0}
                  onclick={() => crud.startEditing(tagItem)}
                >
                  <Edit2 class="w-4 h-4" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete tag"
                  disabled={tagItem.id < 0}
                  onclick={() => (crud.toDelete = tagItem)}
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
    title="Delete Tag"
    itemName={crud.toDelete?.name || "this tag"}
    warningMessage="This action cannot be undone. This will remove the tag from all time entries."
    onConfirm={crud.confirmDelete}
    onClose={() => (crud.toDelete = null)}
  />
</PageLayout>
