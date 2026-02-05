<script lang="ts">
  import { X } from "lucide-svelte";
  import { fade, fly } from "svelte/transition";
  import IconButton from "./IconButton.svelte";

  interface Props {
    open: boolean;
    title?: string;
    onclose?: () => void;
    maxWidth?: string;
    children?: any;
    footer?: any;
  }

  let {
    open = $bindable(),
    title,
    onclose,
    maxWidth = "max-w-md",
    children,
    footer,
  }: Props = $props();

  function close() {
    open = false;
    onclose?.();
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === "Escape" && open) {
      close();
    }
  }

  function springEasing(t: number): number {
    const c4 = (2 * Math.PI) / 3;
    return t === 0
      ? 0
      : t === 1
        ? 1
        : Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center p-4"
    role="dialog"
    aria-modal="true"
    aria-label={title}
    transition:fade={{ duration: 150 }}
  >
    <div
      class="absolute inset-0 bg-black/50 cursor-pointer"
      onclick={close}
      aria-hidden="true"
    ></div>
    <div
      class="relative w-full {maxWidth} bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
      transition:fly={{ y: 30, duration: 400, easing: springEasing }}
    >
      {#if title}
        <div
          class="p-4 border-b border-bg-tertiary flex items-center justify-between"
        >
          <h3 class="font-semibold">{title}</h3>
          <IconButton
            type="button"
            aria-label="Close"
            onclick={close}
          >
            <X class="w-4 h-4" aria-hidden="true" />
          </IconButton>
        </div>
      {/if}
      <div class="p-4 space-y-4">
        {@render children?.()}
      </div>
      {#if footer}
        <div class="p-4 border-t border-bg-tertiary">
          {@render footer()}
        </div>
      {/if}
    </div>
  </div>
{/if}
