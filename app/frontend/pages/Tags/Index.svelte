<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import { page } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { routes } from "../../lib/routes";
  import { Tag, Plus, Edit2, Trash2, Check, X, Hash } from "lucide-svelte";
  import type { Tag as TagType } from "../../types";

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  let tags = $derived(($page.props.tags as TagType[]) || []);

  let editingId: number | null = $state(null);
  let tagToDelete: TagType | null = $state(null);

  let createForm = useForm({
    name: "",
  });

  let editForm = useForm({
    name: "",
  });

  function startEditing(tagItem: TagType) {
    editingId = tagItem.id;
    $editForm.name = tagItem.name;
  }

  function cancelEditing() {
    editingId = null;
    $editForm.reset();
  }

  function handleCreate() {
    if (!workspaceId) return;
    $createForm.post(routes.tags.create(workspaceId), {
      onSuccess: () => {
        $createForm.reset();
      },
    });
  }

  function handleUpdate(tagId: number) {
    if (!workspaceId) return;
    $editForm.patch(routes.tags.update(workspaceId, tagId), {
      onSuccess: () => {
        editingId = null;
        $editForm.reset();
      },
    });
  }

  function confirmDelete() {
    if (tagToDelete && workspaceId) {
      $editForm.delete(routes.tags.delete(workspaceId, tagToDelete.id));
    }
    tagToDelete = null;
  }
</script>

<PageLayout
  title="Tags"
  icon={Tag}
  iconColor="text-bright-yellow"
  variant="narrow"
  flash={$page.props.flash}
>
  <SectionCard title="Create New Tag" icon={Plus} iconColor="text-bright-yellow" bodyClass="p-4">
    <div class="space-y-4">
      <FormField id="tag-name" label="Tag Name">
        {#snippet children({ describedBy })}
          <TextInput
            id="tag-name"
            tone="yellow"
            bind:value={$createForm.name}
            placeholder="Enter tag name..."
            onkeydown={(e) => e.key === "Enter" && $createForm.name && handleCreate()}
            aria-describedby={describedBy}
          />
        {/snippet}
      </FormField>

      <div class="flex justify-end">
        <Button
          tone="yellow"
          onclick={handleCreate}
          disabled={$createForm.processing || !$createForm.name}
        >
          <Plus class="w-4 h-4" />
          Create Tag
        </Button>
      </div>
    </div>
  </SectionCard>

  <SectionCard title={`All Tags (${tags.length})`}>
    {#if tags.length === 0}
      <div class="p-8 text-center text-fg-muted">
        <Hash class="w-12 h-12 mx-auto mb-4 opacity-50" />
        <p>No tags yet. Create your first tag above!</p>
      </div>
    {:else}
      <div class="divide-y divide-bg-tertiary">
        {#each tags as tagItem, i}
          {@const isLast = i === tags.length - 1}
          {#if editingId === tagItem.id}
            <div class="p-4 {isLast ? 'rounded-b-[10px]' : ''} flex items-center gap-4">
              <div class="flex-1">
                <FormField
                  id="edit-tag-{tagItem.id}"
                  label="Tag Name"
                  srOnly
                >
                  {#snippet children({ describedBy })}
                    <TextInput
                      id="edit-tag-{tagItem.id}"
                      tone="yellow"
                      bind:value={$editForm.name}
                      aria-describedby={describedBy}
                    />
                  {/snippet}
                </FormField>
              </div>

              <div class="flex items-center gap-2">
                <IconButton aria-label="Cancel editing" onclick={cancelEditing}>
                  <X class="w-5 h-5" />
                </IconButton>
                <IconButton
                  tone="success"
                  aria-label="Save changes"
                  onclick={() => handleUpdate(tagItem.id)}
                  disabled={$editForm.processing}
                >
                  <Check class="w-5 h-5" />
                </IconButton>
              </div>
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
                  onclick={() => startEditing(tagItem)}
                >
                  <Edit2 class="w-4 h-4" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete tag"
                  onclick={() => (tagToDelete = tagItem)}
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
    open={tagToDelete !== null}
    title="Delete Tag"
    itemName={tagToDelete?.name || "this tag"}
    warningMessage="This action cannot be undone. This will remove the tag from all time entries."
    onConfirm={confirmDelete}
    onClose={() => (tagToDelete = null)}
  />
</PageLayout>
