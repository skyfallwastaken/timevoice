<script lang="ts">
  import { page } from '@inertiajs/svelte'
  import { 
    Clock, 
    Calendar, 
    List, 
    BarChart3, 
    FileText, 
    Settings,
    LogOut,
    ChevronDown
  } from 'lucide-svelte'
  import { router } from '@inertiajs/svelte'

  let { children } = $props()

  const navItems = [
    { href: '/', icon: Clock, label: 'Timer' },
    { href: '/calendar', icon: Calendar, label: 'Calendar' },
    { href: '/entries', icon: List, label: 'Entries' },
    { href: '/reports', icon: BarChart3, label: 'Reports' },
    { href: '/invoices', icon: FileText, label: 'Invoices' },
    { href: '/settings/workspace', icon: Settings, label: 'Settings' },
  ]

  const user = $derived($page.props.auth?.user)
  const workspace = $derived($page.props.auth?.workspace)

  function signOut() {
    router.delete('/signout')
  }

  function handleKeydown(event: KeyboardEvent, item: { href: string; label: string }) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      router.get(item.href)
    }
  }
</script>

<div class="min-h-screen bg-bg-primary text-fg-primary flex">
  <!-- Skip Link for Accessibility -->
  <a href="#main-content" class="skip-link">
    Skip to main content
  </a>

  <!-- Left Rail -->
  <aside class="w-64 bg-bg-secondary border-r border-bg-tertiary flex flex-col" aria-label="Application sidebar">
    <!-- Logo -->
    <div class="p-6 border-b border-bg-tertiary">
      <h1 class="text-2xl font-bold text-bright-purple">Timevoice</h1>
    </div>

    <!-- Workspace Switcher -->
    <div class="p-4 border-b border-bg-tertiary">
      <button 
        class="w-full flex items-center justify-between px-4 py-2 bg-bg-tertiary rounded-[10px] hover:bg-bg-quaternary transition-colors duration-150"
        aria-label="Switch workspace: {workspace?.name || 'Workspace'}"
      >
        <span class="font-medium truncate">{workspace?.name || 'Workspace'}</span>
        <ChevronDown class="w-4 h-4 text-fg-muted" aria-hidden="true" />
      </button>
    </div>

    <!-- Navigation -->
    <nav class="flex-1 p-4 space-y-1" aria-label="Main navigation">
      {#each navItems as item}
        {@const isActive = $page.url === item.href || $page.url.startsWith(item.href + '/')}
        <a
          href={item.href}
          class="flex items-center gap-3 px-4 py-3 rounded-[10px] transition-colors duration-150 {isActive ? 'bg-bright-purple/20 text-bright-purple' : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
          aria-current={isActive ? 'page' : undefined}
        >
          <item.icon class="w-5 h-5" aria-hidden="true" />
          <span class="font-medium">{item.label}</span>
        </a>
      {/each}
    </nav>

    <!-- User Section -->
    <div class="p-4 border-t border-bg-tertiary">
      <div class="flex items-center gap-3 px-4 py-3">
        {#if user?.avatar_url}
          <img src={user.avatar_url} alt="" class="w-10 h-10 rounded-full" />
        {:else}
          <div class="w-10 h-10 rounded-full bg-bg-tertiary flex items-center justify-center text-lg font-semibold" aria-hidden="true">
            {user?.name?.[0]?.toUpperCase() || '?'}
          </div>
        {/if}
        <div class="flex-1 min-w-0">
          <p class="font-medium truncate" id="user-name">{user?.name}</p>
          <p class="text-sm text-fg-muted truncate" id="user-email">{user?.email}</p>
        </div>
      </div>
      <button
        onclick={signOut}
        class="w-full flex items-center gap-3 px-4 py-2 mt-2 text-fg-muted hover:text-bright-red transition-colors duration-150 rounded-[10px] focus-visible:ring-2 focus-visible:ring-bright-blue"
        aria-label="Sign out {user?.name}"
      >
        <LogOut class="w-5 h-5" aria-hidden="true" />
        <span>Sign out</span>
      </button>
    </div>
  </aside>

  <!-- Main Content -->
  <main id="main-content" class="flex-1 flex flex-col min-w-0" tabindex="-1">
    {@render children()}
  </main>
</div>
