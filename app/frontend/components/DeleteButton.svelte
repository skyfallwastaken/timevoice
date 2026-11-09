<script module lang="ts">
  // Shared by every delete button on the page.
  let shiftHeld = $state(false);
  // The one hovered button's tooltip ID; while set, a focused button defers.
  let hoveredId = $state<string | null>(null);
</script>

<script lang="ts">
  import { Trash2 } from "@lucide/svelte";
  import { onDestroy, type ComponentProps } from "svelte";
  import IconButton from "./IconButton.svelte";

  type Props = Omit<ComponentProps<typeof IconButton>, "children" | "tone"> & {
    /** Deletes without asking; runs instead of onclick on Shift+click. */
    onShiftClick: () => void;
  };

  let { onclick, onShiftClick, ...rest }: Props = $props();
  const id = $props.id();
  let focused = $state(false);
  let showTooltip = $derived(
    shiftHeld &&
      !rest.disabled &&
      (hoveredId === id || (hoveredId === null && focused)),
  );

  // A Shift+click deletes the row under the pointer without a pointerleave.
  onDestroy(() => {
    if (hoveredId === id) hoveredId = null;
  });
</script>

<svelte:window
  onkeydown={(e) => (shiftHeld = e.shiftKey || e.key === "Shift")}
  onkeyup={(e) => (shiftHeld = e.shiftKey && e.key !== "Shift")}
  onblur={() => (shiftHeld = false)}
/>

<span class="relative inline-flex">
  <IconButton
    tone="danger"
    onpointerenter={(e) => {
      hoveredId = id;
      shiftHeld = e.shiftKey;
    }}
    onpointerleave={() => {
      if (hoveredId === id) hoveredId = null;
    }}
    onfocus={(e) => (focused = e.currentTarget.matches(":focus-visible"))}
    onblur={() => (focused = false)}
    onclick={(e) => (e.shiftKey ? onShiftClick() : onclick?.(e))}
    aria-describedby={showTooltip ? id : undefined}
    {...rest}
  >
    <Trash2 class="w-4 h-4" aria-hidden="true" />
  </IconButton>
  {#if showTooltip}
    <span
      {id}
      role="tooltip"
      class="pointer-events-none absolute bottom-full right-0 z-20 mb-2 whitespace-nowrap rounded-md bg-bright-red px-2 py-1 text-xs font-medium text-bg-primary after:absolute after:top-full after:right-3 after:border-4 after:border-transparent after:border-t-bright-red"
    >
      Click to delete without confirming
    </span>
  {/if}
</span>
