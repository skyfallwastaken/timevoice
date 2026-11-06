<script lang="ts">
  import type { Snippet } from "svelte";
  import { X } from "lucide-svelte";
  import * as Dialog from "$lib/components/ui/dialog/index.js";
  import { cn } from "$lib/utils.js";

  interface Props {
    open: boolean;
    title?: string;
    onclose?: () => void;
    maxWidth?: string;
    children?: Snippet;
    footer?: Snippet;
  }

  let {
    open = $bindable(),
    title,
    onclose,
    maxWidth = "max-w-md",
    children,
    footer,
  }: Props = $props();
</script>

<Dialog.Root
  bind:open
  onOpenChange={(isOpen) => {
    if (!isOpen) onclose?.();
  }}
>
  <Dialog.Content
    showCloseButton={false}
    class={cn(
      "w-[calc(100%-2rem)] max-h-[90vh] flex flex-col gap-0 p-0 overflow-hidden text-sm",
      maxWidth,
    )}
  >
    {#if title}
      <div
        class="p-4 border-b border-bg-tertiary flex items-center justify-between shrink-0"
      >
        <Dialog.Title class="font-semibold">{title}</Dialog.Title>
        <Dialog.Close
          class="inline-flex items-center justify-center rounded-[10px] p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
          aria-label="Close"
        >
          <X class="w-4 h-4" aria-hidden="true" />
        </Dialog.Close>
      </div>
    {/if}
    <div class="p-4 space-y-4 overflow-y-auto">
      {@render children?.()}
    </div>
    {#if footer}
      <div class="p-4 border-t border-bg-tertiary shrink-0">
        {@render footer()}
      </div>
    {/if}
  </Dialog.Content>
</Dialog.Root>
