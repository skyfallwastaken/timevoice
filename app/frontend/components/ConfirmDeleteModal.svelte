<script lang="ts">
  import Modal from "./Modal.svelte";
  import Button from "./Button.svelte";

  interface Props {
    open: boolean;
    title: string;
    itemName: string;
    warningMessage: string;
    onConfirm: () => void;
    onClose: () => void;
    details?: any;
  }

  let {
    open = $bindable(),
    title,
    itemName,
    warningMessage,
    onConfirm,
    onClose,
    details,
  }: Props = $props();
</script>

<Modal {open} {title} onclose={onClose}>
  <div class="space-y-4">
    <p class="text-fg-primary">
      Are you sure you want to delete <span class="font-semibold">{itemName}</span
      >?
    </p>
    {#if details}
      {@render details()}
    {/if}
    <p class="text-sm text-fg-muted">
      {warningMessage}
    </p>
  </div>

  {#snippet footer()}
    <div class="flex items-center justify-end gap-2">
      <Button variant="ghost" onclick={onClose}>
        Cancel
      </Button>
      <Button tone="red" onclick={onConfirm}>
        {title}
      </Button>
    </div>
  {/snippet}
</Modal>
