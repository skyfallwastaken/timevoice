<script lang="ts">
  interface Props {
    title: string;
    icon?: any;
    iconColor?: string;
    children: import("svelte").Snippet;
    headerActions?: import("svelte").Snippet;
    breadcrumb?: import("svelte").Snippet;
  }

  let {
    title,
    icon: IconComponent,
    iconColor = "text-bright-blue",
    children,
    headerActions,
    breadcrumb,
  }: Props = $props();
</script>

<div class="flex-1 p-4 sm:p-6 overflow-auto">
  <div class="max-w-5xl mx-auto space-y-6">
    {#if breadcrumb}
      <div class="-mb-2">{@render breadcrumb()}</div>
    {/if}
    <div
      class="flex flex-col sm:flex-row sm:items-center justify-between gap-3"
    >
      <div class="flex items-center gap-3 min-w-0 sm:shrink-0">
        {#if IconComponent}
          <IconComponent class="w-6 h-6 {iconColor}" aria-hidden="true" />
        {/if}
        <h2 class="text-xl sm:text-2xl font-semibold tracking-tight truncate">
          {title}
        </h2>
      </div>
      {#if headerActions}
        <div class="flex items-center gap-2 min-w-0 sm:flex-1 sm:justify-end">
          {@render headerActions()}
        </div>
      {/if}
    </div>

    {@render children()}
  </div>
</div>
