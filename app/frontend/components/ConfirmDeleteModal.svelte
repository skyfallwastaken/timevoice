<script lang="ts">
  import type { Snippet } from "svelte";
  import { AlertDialog as AlertDialogPrimitive } from "bits-ui";
  import * as AlertDialog from "$lib/components/ui/alert-dialog/index.js";
  import Button from "./Button.svelte";
  import TextInput from "./TextInput.svelte";

  interface Props {
    open: boolean;
    title: string;
    itemName: string;
    warningMessage: string;
    /** Receives the typed confirmation text when `confirmText` is set. */
    onConfirm: (typed: string) => void;
    onClose: () => void;
    actionVerb?: string;
    confirmLabel?: string;
    details?: Snippet;
    /** When set, the confirm button stays disabled until this exact text is typed. */
    confirmText?: string;
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
    confirmText,
  }: Props = $props();

  let typed = $state("");
  $effect(() => {
    if (open) typed = "";
  });
  const confirmed = $derived(!confirmText || typed === confirmText);

  function confirmFromInput(event: KeyboardEvent) {
    if (event.key !== "Enter" || event.isComposing || !confirmed) return;
    event.preventDefault();
    onConfirm(typed);
    open = false;
  }

  // Callers often clear the item as the dialog closes, so keep showing what it
  // opened with while it fades out.
  const text = () => ({
    title,
    itemName,
    warningMessage,
    actionVerb,
    confirmLabel,
  });
  let lastShown = text();
  const shown = $derived.by(() => (open ? (lastShown = text()) : lastShown));
</script>

<AlertDialog.Root
  bind:open
  onOpenChange={(isOpen) => {
    if (!isOpen) onClose();
  }}
>
  <AlertDialog.Content
    class="w-[calc(100%-2rem)] data-[size=default]:max-w-md data-[size=default]:sm:max-w-md gap-0 p-0 text-sm"
  >
    <div class="p-4 border-b border-bg-tertiary">
      <AlertDialog.Title class="font-semibold text-base"
        >{shown.title}</AlertDialog.Title
      >
    </div>
    <div class="p-4 space-y-4">
      <AlertDialog.Description class="text-fg-primary text-sm">
        Are you sure you want to {shown.actionVerb}
        <span class="font-semibold">{shown.itemName}</span>?
      </AlertDialog.Description>
      {#if details}
        {@render details()}
      {/if}
      <p class="text-sm text-fg-muted">
        {shown.warningMessage}
      </p>
      {#if confirmText}
        <div>
          <label
            for="confirm-delete-text"
            class="block text-sm font-medium text-fg-secondary mb-1"
          >
            Type <span class="font-semibold text-fg-primary">{confirmText}</span
            > to confirm
          </label>
          <TextInput
            id="confirm-delete-text"
            tone="red"
            bind:value={typed}
            autocomplete="off"
            spellcheck={false}
            onkeydown={confirmFromInput}
          />
        </div>
      {/if}
    </div>
    <div
      class="p-4 border-t border-bg-tertiary flex items-center justify-end gap-2"
    >
      <AlertDialogPrimitive.Cancel>
        {#snippet child({ props })}
          <Button variant="ghost" {...props}>Cancel</Button>
        {/snippet}
      </AlertDialogPrimitive.Cancel>
      <AlertDialogPrimitive.Action onclick={() => onConfirm(typed)}>
        {#snippet child({ props })}
          <Button tone="red" {...props} disabled={!confirmed}
            >{shown.confirmLabel}</Button
          >
        {/snippet}
      </AlertDialogPrimitive.Action>
    </div>
  </AlertDialog.Content>
</AlertDialog.Root>
