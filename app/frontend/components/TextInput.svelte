<script lang="ts">
  import type { HTMLInputAttributes } from "svelte/elements";

  interface Props extends HTMLInputAttributes {
    value?: string;
    tone?: "blue" | "green" | "yellow" | "purple" | "red";
    inputRef?: HTMLInputElement | null;
  }

  let {
    value = $bindable(),
    inputRef = $bindable(null),
    type = "text",
    tone = "blue",
    class: className = "",
    disabled = false,
    ...rest
  }: Props = $props();

  const baseClass =
    "w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed";

  const toneClasses = {
    blue: "focus:border-bright-blue",
    green: "focus:border-bright-green",
    yellow: "focus:border-bright-yellow",
    purple: "focus:border-bright-purple",
    red: "focus:border-bright-red",
  };

  let toneClass = $derived(toneClasses[tone]);
</script>

<input
  {type}
  {disabled}
  bind:value
  bind:this={inputRef}
  class="{baseClass} {toneClass} {className}"
  {...rest}
/>
