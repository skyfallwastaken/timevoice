<script lang="ts">
  import type { HTMLButtonAttributes } from "svelte/elements";

  interface Props extends HTMLButtonAttributes {
    tone?: "default" | "danger" | "primary" | "success";
    size?: "sm" | "md" | "lg";
    children?: import("svelte").Snippet;
  }

  let {
    tone = "default",
    size = "md",
    type = "button",
    disabled = false,
    class: className = "",
    children,
    ...rest
  }: Props = $props();

  const baseClass =
    "inline-flex items-center justify-center rounded-[10px] transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed";

  const sizeClasses = {
    sm: "p-1.5",
    md: "p-2",
    lg: "p-3",
  };

  const toneClasses = {
    default: "text-fg-muted hover:text-fg-primary",
    danger: "text-fg-muted hover:text-bright-red",
    primary: "text-bright-blue hover:text-accent-blue",
    success: "text-bright-green hover:text-accent-green",
  };

  let sizeClass = $derived(sizeClasses[size]);
  let toneClass = $derived(toneClasses[tone]);
</script>

<button
  {type}
  {disabled}
  class="{baseClass} {sizeClass} {toneClass} {className}"
  {...rest}
>
  {@render children?.()}
</button>
