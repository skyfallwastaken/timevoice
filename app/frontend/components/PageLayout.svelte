<script lang="ts">
  import type { Component } from 'svelte'

  interface Flash {
    notice?: string
    alert?: string
  }

  interface Props {
    title: string
    icon?: any
    iconColor?: string
    variant?: 'wide' | 'narrow'
    flash?: Flash
    children: import('svelte').Snippet
    headerActions?: import('svelte').Snippet
  }

  let { 
    title, 
    icon: IconComponent, 
    iconColor = 'text-bright-blue',
    variant = 'narrow',
    flash,
    children,
    headerActions
  }: Props = $props()

  const maxWidthClass = $derived(variant === 'wide' ? 'max-w-6xl' : 'max-w-4xl')
</script>

<div class="flex-1 p-4 sm:p-6 overflow-auto">
  <div class="{maxWidthClass} mx-auto space-y-6">
    <!-- Page Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
      <div class="flex items-center gap-3 min-w-0">
        {#if IconComponent}
          <IconComponent class="w-6 h-6 {iconColor}" aria-hidden="true" />
        {/if}
        <h2 class="text-xl sm:text-2xl font-semibold truncate">{title}</h2>
      </div>
      {#if headerActions}
        <div class="flex items-center gap-2 sm:justify-end">
          {@render headerActions()}
        </div>
      {/if}
    </div>

    <!-- Flash Messages -->
    {#if flash?.notice}
      <div class="bg-bright-green/10 border border-bright-green text-bright-green px-4 py-3 rounded-[10px] animate-slide-in" role="alert">
        {flash.notice}
      </div>
    {/if}
    {#if flash?.alert}
      <div class="bg-bright-red/10 border border-bright-red text-bright-red px-4 py-3 rounded-[10px] animate-slide-in" role="alert">
        {flash.alert}
      </div>
    {/if}

    <!-- Page Content -->
    {@render children()}
  </div>
</div>
