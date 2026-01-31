<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import type { Snippet } from 'svelte'

  interface Props {
    href: string
    children: Snippet
    class?: string
    preserveScroll?: boolean
    preserveState?: boolean
    replace?: boolean
    [key: string]: any
  }

  let { 
    href, 
    children, 
    class: className = '', 
    preserveScroll = false,
    preserveState = false,
    replace = false,
    ...restProps
  }: Props = $props()

  function handleClick(e: MouseEvent) {
    // Allow default behavior for:
    // - Ctrl/Cmd + click (open in new tab)
    // - Shift + click (open in new window)
    // - Middle mouse button
    // - External links (non-relative paths)
    if (e.ctrlKey || e.metaKey || e.shiftKey) return
    if (e.button !== 0) return
    if (href.startsWith('http') || href.startsWith('//')) return
    if (restProps.target && restProps.target !== '_self') return

    e.preventDefault()
    
    router.get(href, {}, {
      preserveScroll,
      preserveState,
      replace,
    })
  }
</script>

<a 
  {href} 
  class={className}
  onclick={handleClick}
  {...restProps}
>
  {@render children()}
</a>
