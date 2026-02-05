<script lang="ts">
  import type { HTMLButtonAttributes } from "svelte/elements";

  interface Props extends HTMLButtonAttributes {
    variant?: "primary" | "secondary" | "ghost" | "outline";
    tone?: "blue" | "green" | "purple" | "yellow" | "red";
    size?: "sm" | "md" | "lg";
    children?: import("svelte").Snippet;
  }

  let {
    variant = "primary",
    tone = "blue",
    size = "md",
    type = "button",
    disabled = false,
    class: className = "",
    children,
    ...rest
  }: Props = $props();

  const baseClass =
    "inline-flex items-center justify-center gap-2 rounded-[10px] transition-colors duration-150 font-medium disabled:opacity-50 disabled:cursor-not-allowed";

  const sizeClasses = {
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2",
    lg: "px-6 py-3 text-lg",
  };

  const toneClasses = {
    blue: "bg-bright-blue hover:bg-accent-blue text-bg-primary",
    green: "bg-bright-green hover:bg-accent-green text-bg-primary",
    purple: "bg-bright-purple hover:bg-accent-purple text-bg-primary",
    yellow: "bg-bright-yellow hover:bg-accent-yellow text-bg-primary",
    red: "bg-bright-red hover:bg-accent-red text-bg-primary",
  };

  const variantClasses = {
    primary: toneClasses,
    secondary: {
      blue: "bg-bg-secondary border border-bg-tertiary hover:bg-bg-tertiary text-fg-primary",
      green: "bg-bg-secondary border border-bg-tertiary hover:bg-bg-tertiary text-fg-primary",
      purple: "bg-bg-secondary border border-bg-tertiary hover:bg-bg-tertiary text-fg-primary",
      yellow: "bg-bg-secondary border border-bg-tertiary hover:bg-bg-tertiary text-fg-primary",
      red: "bg-bg-secondary border border-bg-tertiary hover:bg-bg-tertiary text-fg-primary",
    },
    ghost: {
      blue: "text-fg-muted hover:text-fg-primary",
      green: "text-fg-muted hover:text-fg-primary",
      purple: "text-fg-muted hover:text-fg-primary",
      yellow: "text-fg-muted hover:text-fg-primary",
      red: "text-fg-muted hover:text-fg-primary",
    },
    outline: {
      blue: "border border-bg-tertiary text-fg-muted hover:text-fg-primary hover:border-bright-blue",
      green: "border border-bg-tertiary text-fg-muted hover:text-fg-primary hover:border-bright-blue",
      purple: "border border-bg-tertiary text-fg-muted hover:text-fg-primary hover:border-bright-blue",
      yellow: "border border-bg-tertiary text-fg-muted hover:text-fg-primary hover:border-bright-blue",
      red: "border border-bg-tertiary text-fg-muted hover:text-fg-primary hover:border-bright-blue",
    },
  };

  let sizeClass = $derived(sizeClasses[size]);
  let variantClass = $derived(variantClasses[variant][tone]);
</script>

<button
  {type}
  {disabled}
  class="{baseClass} {sizeClass} {variantClass} {className}"
  {...rest}
>
  {@render children?.()}
</button>
