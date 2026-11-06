<script lang="ts">
  import type { HTMLSelectAttributes } from "svelte/elements";
  import { cn } from "$lib/utils.js";

  interface Props extends HTMLSelectAttributes {
    value?: string | number;
    tone?: "blue" | "green" | "yellow" | "purple" | "red";
    children?: import("svelte").Snippet;
  }

  let {
    value = $bindable(),
    tone = "blue",
    class: className = "",
    disabled = false,
    children,
    ...rest
  }: Props = $props();

  const baseClass =
    "w-full bg-bg-primary border border-bg-tertiary rounded-[10px] h-9 px-3 text-base md:text-sm text-fg-primary focus:outline-none transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed";

  const toneClasses = {
    blue: "focus:border-bright-blue",
    green: "focus:border-bright-green",
    yellow: "focus:border-bright-yellow",
    purple: "focus:border-bright-purple",
    red: "focus:border-bright-red",
  };

  let toneClass = $derived(toneClasses[tone]);
</script>

<select
  {disabled}
  bind:value
  class={cn(baseClass, toneClass, className)}
  {...rest}
>
  {@render children?.()}
</select>
