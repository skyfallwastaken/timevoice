<script lang="ts">
  import type { Component } from 'svelte'

  let { 
    icon: Icon,
    title,
    description,
    actionLabel = null,
    actionHref = null,
    onAction = null
  }: {
    icon: Component
    title: string
    description: string
    actionLabel?: string | null
    actionHref?: string | null
    onAction?: (() => void) | null
  } = $props()
</script>

<div class="flex flex-col items-center justify-center py-12 px-4 text-center">
  <div class="w-16 h-16 rounded-full bg-bg-tertiary flex items-center justify-center mb-4">
    <Icon class="w-8 h-8 text-fg-muted" />
  </div>
  
  <h3 class="text-lg font-semibold text-fg-primary mb-2">
    {title}
  </h3>
  
  <p class="text-fg-muted max-w-sm mb-6">
    {description}
  </p>
  
  {#if actionLabel && (actionHref || onAction)}
    {#if actionHref}
      <a 
        href={actionHref}
        class="px-4 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] transition-colors duration-150 font-medium"
      >
        {actionLabel}
      </a>
    {:else if onAction}
      <button 
        onclick={onAction}
        class="px-4 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] transition-colors duration-150 font-medium"
      >
        {actionLabel}
      </button>
    {/if}
  {/if}
</div>
