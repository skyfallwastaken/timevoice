<script lang="ts">
  import { page, router } from "@inertiajs/svelte";
  import Modal from "./Modal.svelte";
  import Button from "./Button.svelte";
  import FormField from "./FormField.svelte";
  import SelectInput from "./SelectInput.svelte";
  import ChipButton from "./ChipButton.svelte";
  import { routes } from "../lib/routes";
  import { toggleSelectedTag } from "../lib/time-entry-form";
  import type { Project, Tag } from "../types";

  interface Props {
    ids: number[];
    projects: Project[];
    tags: Tag[];
    open: boolean;
    onClose: () => void;
    onSaved: () => void;
  }

  let { ids, projects, tags, open, onClose, onSaved }: Props = $props();

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  let project = $state("keep");
  let billable = $state("keep");
  let addTagIds = $state<number[]>([]);
  let processing = $state(false);
  // Saving clears the selection as the dialog closes, so show the count it
  // opened with while it fades out.
  let count = $state(0);

  $effect(() => {
    if (open) {
      count = ids.length;
      project = "keep";
      billable = "keep";
      addTagIds = [];
    }
  });

  let hasChanges = $derived(
    project !== "keep" || billable !== "keep" || addTagIds.length > 0,
  );

  function save() {
    const changes: Record<string, string | boolean | number[]> = {
      add_tag_ids: addTagIds,
    };
    if (project !== "keep")
      changes.project_id = project === "none" ? "" : project;
    if (billable !== "keep") changes.billable = billable === "billable";

    router.patch(
      routes.timeEntries.bulkUpdate(workspaceId),
      { ids, changes },
      {
        preserveScroll: true,
        onStart: () => (processing = true),
        onFinish: () => (processing = false),
        onSuccess: onSaved,
      },
    );
  }
</script>

<Modal
  {open}
  title={`Edit ${count} ${count === 1 ? "entry" : "entries"}`}
  onclose={onClose}
  maxWidth="max-w-lg"
>
  <p class="text-sm text-fg-muted">
    Fields you leave unchanged keep each entry's current value.
  </p>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <FormField id="bulk-project" label="Project">
      {#snippet children({ describedBy })}
        <SelectInput
          id="bulk-project"
          bind:value={project}
          aria-describedby={describedBy}
        >
          <option value="keep">Don't change</option>
          <option value="none">No project</option>
          {#each projects as p}
            <option value={p.id.toString()}>{p.name}</option>
          {/each}
        </SelectInput>
      {/snippet}
    </FormField>

    <FormField id="bulk-billable" label="Billable">
      {#snippet children({ describedBy })}
        <SelectInput
          id="bulk-billable"
          bind:value={billable}
          aria-describedby={describedBy}
        >
          <option value="keep">Don't change</option>
          <option value="billable">Billable</option>
          <option value="non-billable">Non-billable</option>
        </SelectInput>
      {/snippet}
    </FormField>
  </div>

  {#if tags.length > 0}
    <div>
      <span class="block text-sm font-medium text-fg-secondary mb-2"
        >Add tags</span
      >
      <div class="flex flex-wrap gap-2">
        {#each tags as tag}
          <ChipButton
            selected={addTagIds.includes(tag.id)}
            aria-pressed={addTagIds.includes(tag.id)}
            onclick={() => (addTagIds = toggleSelectedTag(addTagIds, tag.id))}
          >
            {tag.name}
          </ChipButton>
        {/each}
      </div>
    </div>
  {/if}

  {#snippet footer()}
    <div class="flex justify-end gap-2">
      <Button variant="ghost" onclick={onClose}>Cancel</Button>
      <Button tone="purple" disabled={!hasChanges || processing} onclick={save}>
        Update {count}
        {count === 1 ? "entry" : "entries"}
      </Button>
    </div>
  {/snippet}
</Modal>
