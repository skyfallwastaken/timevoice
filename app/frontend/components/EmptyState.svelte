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

  <h3 class="text-lg font-semibold text-fg-primary mb-2">
    {title}
  </h3>

  <p class="text-fg-muted max-w-sm mb-6">
    {description}
  </p>

  {#if actionLabel && actionHref}
    <Link href={actionHref}>
      <Button tone="purple" size="md">{actionLabel}</Button>
    </Link>
  {:else if actionLabel && onAction}
    <Button tone="purple" size="md" onclick={onAction}>{actionLabel}</Button>
  {/if}
</div>
