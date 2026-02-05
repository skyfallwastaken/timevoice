<script lang="ts">
  interface Props {
    dense?: boolean;
    class?: string;
    contentClass?: string;
    primaryClass?: string;
    secondaryClass?: string;
    metaClass?: string;
    actionsClass?: string;
    leadingClass?: string;
    leading?: import("svelte").Snippet;
    primary: import("svelte").Snippet;
    secondary?: import("svelte").Snippet;
    meta?: import("svelte").Snippet;
    actions?: import("svelte").Snippet;
  }

  let {
    dense = false,
    class: className = "",
    contentClass = "",
    primaryClass = "",
    secondaryClass = "",
    metaClass = "",
    actionsClass = "",
    leadingClass = "",
    leading,
    primary,
    secondary,
    meta,
    actions,
  }: Props = $props();

  let paddingClass = $derived(dense ? "p-3" : "p-4");
</script>

<div
  class="{paddingClass} flex items-center justify-between gap-4 hover:bg-bg-tertiary/50 transition-colors duration-150 {className}"
>
  <div class="flex items-center gap-3 min-w-0 flex-1 {contentClass}">
    {#if leading}
      <div class="flex-shrink-0 {leadingClass}">
        {@render leading()}
      </div>
    {/if}
    <div class="min-w-0">
      <div class="font-medium truncate {primaryClass}">
        {@render primary()}
      </div>
      {#if secondary}
        <div class="text-sm text-fg-muted truncate {secondaryClass}">
          {@render secondary()}
        </div>
      {/if}
    </div>
  </div>

  {#if meta}
    <div class="text-sm text-fg-muted text-right {metaClass}">
      {@render meta()}
    </div>
  {/if}

  {#if actions}
    <div class="flex items-center gap-2 shrink-0 {actionsClass}">
      {@render actions()}
    </div>
  {/if}
</div>
