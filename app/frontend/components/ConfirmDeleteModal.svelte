<script lang="ts">
  import type { Snippet } from "svelte";
  import { AlertDialog as AlertDialogPrimitive } from "bits-ui";
  import * as AlertDialog from "$lib/components/ui/alert-dialog/index.js";
  import Button from "./Button.svelte";

  interface Props {
    open: boolean;
    title: string;
    itemName: string;
    warningMessage: string;
    onConfirm: () => void;
    onClose: () => void;
    actionVerb?: string;
    confirmLabel?: string;
    details?: Snippet;
  }

  let {
    open = $bindable(),
    title,
    itemName,
    warningMessage,
    onConfirm,
    onClose,
    actionVerb = "delete",
    confirmLabel = title,
    details,
  }: Props = $props();
</script>

<AlertDialog.Root
  bind:open
  onOpenChange={(isOpen) => {
    if (!isOpen) onClose();
  }}
>
  <AlertDialog.Content
    class="w-[calc(100%-2rem)] data-[size=default]:max-w-md data-[size=default]:sm:max-w-md gap-0 p-0 text-base"
  >
    <div class="p-4 border-b border-bg-tertiary">
      <AlertDialog.Title class="font-semibold text-base"
        >{title}</AlertDialog.Title
      >
    </div>
    <div class="p-4 space-y-4">
      <AlertDialog.Description class="text-fg-primary text-base">
        Are you sure you want to {actionVerb}
        <span class="font-semibold">{itemName}</span>?
      </AlertDialog.Description>
      {#if details}
        {@render details()}
      {/if}
      <p class="text-sm text-fg-muted">
        {warningMessage}
      </p>
    </div>
    <div
      class="p-4 border-t border-bg-tertiary flex items-center justify-end gap-2"
    >
      <AlertDialogPrimitive.Cancel>
        {#snippet child({ props })}
          <Button variant="ghost" {...props}>Cancel</Button>
        {/snippet}
      </AlertDialogPrimitive.Cancel>
      <AlertDialogPrimitive.Action onclick={onConfirm}>
        {#snippet child({ props })}
          <Button tone="red" {...props}>{confirmLabel}</Button>
        {/snippet}
      </AlertDialogPrimitive.Action>
    </div>
  </AlertDialog.Content>
</AlertDialog.Root>
