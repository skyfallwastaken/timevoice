<script lang="ts">
  import type { HTMLButtonAttributes } from "svelte/elements";

  interface Props extends HTMLButtonAttributes {
    selected?: boolean;
    children?: import("svelte").Snippet;
  }

  let {
    selected = false,
    type = "button",
    disabled = false,
    class: className = "",
    children,
    ...rest
  }: Props = $props();

  const baseClass =
    "inline-flex items-center gap-2 px-3 py-1.5 text-sm rounded-[10px] border transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed";

  let selectedClass = $derived(
    selected
      ? "border-bright-purple text-bright-purple"
      : "bg-bg-primary border-bg-tertiary text-fg-secondary hover:bg-bg-tertiary hover:border-bright-purple"
  );
</script>

<button
  {type}
  {disabled}
  class="{baseClass} {selectedClass} {className}"
  {...rest}
>
  {@render children?.()}
</button>
