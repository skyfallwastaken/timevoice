<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "./Button.svelte";

  let {
    icon: Icon,
    title,
    description,
    actionLabel = null,
    actionHref = null,
    onAction = null,
  }: {
    icon: any;
    title: string;
    description: string;
    actionLabel?: string | null;
    actionHref?: string | null;
    onAction?: (() => void) | null;
  } = $props();
</script>

<div class="flex flex-col items-center justify-center py-12 px-4 text-center">
  <div
    class="w-16 h-16 rounded-full bg-bg-tertiary flex items-center justify-center mb-4"
  >
    <Icon class="w-8 h-8 text-fg-muted" />
  </div>

  <h3 class="text-base font-semibold text-fg-primary mb-1">
    {title}
  </h3>

  <p class="text-sm text-fg-muted max-w-sm mb-6">
    {description}
  </p>

  {#if actionLabel && actionHref}
    <Link
      href={actionHref}
      class="inline-flex items-center justify-center gap-2 h-9 px-4 rounded-[10px] text-sm font-medium bg-bright-purple hover:bg-accent-purple text-bg-primary transition-colors duration-150"
    >
      {actionLabel}
    </Link>
  {:else if actionLabel && onAction}
    <Button tone="purple" size="md" onclick={onAction}>{actionLabel}</Button>
  {/if}
</div>
