<script lang="ts">
  import Modal from "./Modal.svelte";

  interface Props {
    open: boolean;
    title: string;
    itemName: string;
    warningMessage: string;
    onConfirm: () => void;
    onClose: () => void;
  }

  let {
    open = $bindable(),
    title,
    itemName,
    warningMessage,
    onConfirm,
    onClose,
  }: Props = $props();
</script>

<Modal {open} {title} onclose={onClose}>
  <div class="space-y-4">
    <p class="text-fg-primary">
      Are you sure you want to delete <span class="font-semibold">{itemName}</span
      >?
    </p>
    <p class="text-sm text-fg-muted">
      {warningMessage}
    </p>
  </div>

  {#snippet footer()}
    <div class="flex items-center justify-end gap-2">
      <button
        type="button"
        class="px-4 py-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
        onclick={onClose}
      >
        Cancel
      </button>
      <button
        type="button"
        class="px-4 py-2 bg-bright-red hover:bg-accent-red text-bg-primary rounded-[10px] transition-colors duration-150 font-medium"
        onclick={onConfirm}
      >
        {title}
      </button>
    </div>
  {/snippet}
</Modal>
