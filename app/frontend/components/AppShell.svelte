<script lang="ts">
  import { page } from '@inertiajs/svelte'
  import { 
    Clock, 
    Calendar, 
    List, 
    FolderKanban,
    BarChart3, 
    FileText, 
    Building2,
    Tag,
    Settings,
    LogOut,
    ChevronDown,
    Menu,
    X
  } from 'lucide-svelte'
  import { router } from '@inertiajs/svelte'

  let { children } = $props()

  const navItems = [
    { href: '/', icon: Clock, label: 'Timer' },
    { href: '/calendar', icon: Calendar, label: 'Calendar' },
    { href: '/entries', icon: List, label: 'Entries' },
    { href: '/clients', icon: Building2, label: 'Clients' },
    { href: '/projects', icon: FolderKanban, label: 'Projects' },
    { href: '/tags', icon: Tag, label: 'Tags' },
    { href: '/reports', icon: BarChart3, label: 'Reports' },
    { href: '/invoices', icon: FileText, label: 'Invoices' },
    { href: '/settings/workspace', icon: Settings, label: 'Settings' },
  ]

  const user = $derived($page.props.auth?.user)
  const workspace = $derived($page.props.auth?.workspace)
  const workspaces = $derived($page.props.auth?.workspaces || [])

  let mobileNavOpen = $state(false)
  let mobileWorkspaceOpen = $state(false)
  let desktopWorkspaceOpen = $state(false)

  function signOut() {
    router.delete('/signout')
  }

  function closeMobileNav() {
    mobileNavOpen = false
    mobileWorkspaceOpen = false
  }

  function switchWorkspace(workspaceId: number) {
    router.patch(
      '/workspaces/switch',
      { workspace_id: workspaceId },
      {
        preserveScroll: true,
        onSuccess: () => {
          desktopWorkspaceOpen = false
          mobileWorkspaceOpen = false
          closeMobileNav()
        }
      }
    )
  }

  $effect(() => {
    if (!mobileNavOpen) return

    const onKeydown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') closeMobileNav()
    }

    window.addEventListener('keydown', onKeydown)
    return () => window.removeEventListener('keydown', onKeydown)
  })

</script>

<div class="h-screen bg-bg-primary text-fg-primary flex overflow-hidden">
  <!-- Skip Link for Accessibility -->
  <a href="#main-content" class="skip-link">
    Skip to main content
  </a>

  <!-- Mobile Top Bar -->
  <header class="md:hidden fixed top-0 left-0 right-0 z-30 bg-bg-secondary border-b border-bg-tertiary">
    <div class="h-14 px-4 flex items-center justify-between">
      <button
        type="button"
        class="p-2 rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
        onclick={() => mobileNavOpen = true}
        aria-label="Open navigation"
      >
        <Menu class="w-5 h-5" aria-hidden="true" />
      </button>

      <div class="min-w-0 text-center">
        <p class="text-sm font-semibold truncate">{workspace?.name || 'Workspace'}</p>
        <p class="text-xs text-fg-muted truncate">{user?.name || ''}</p>
      </div>

      <button
        type="button"
        class="p-2 rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
        onclick={signOut}
        aria-label="Sign out"
      >
        <LogOut class="w-5 h-5" aria-hidden="true" />
      </button>
    </div>
  </header>

  <!-- Mobile Drawer -->
  {#if mobileNavOpen}
    <div class="md:hidden fixed inset-0 z-40" aria-label="Mobile navigation">
      <div class="absolute inset-0 bg-black/50" onclick={closeMobileNav} aria-hidden="true"></div>
      <aside class="absolute left-0 top-0 bottom-0 w-80 max-w-[85vw] bg-bg-secondary border-r border-bg-tertiary flex flex-col">
        <div class="p-4 border-b border-bg-tertiary flex items-center justify-between">
          <h1 class="text-lg font-bold text-bright-purple">Timevoice</h1>
          <button
            type="button"
            class="p-2 rounded-[10px] hover:bg-bg-tertiary transition-colors duration-150"
            onclick={closeMobileNav}
            aria-label="Close navigation"
          >
            <X class="w-5 h-5" aria-hidden="true" />
          </button>
        </div>

        <div class="p-4 border-b border-bg-tertiary">
          <button
            type="button"
            class="w-full flex items-center justify-between px-4 py-2 bg-bg-tertiary rounded-[10px] hover:bg-bg-quaternary transition-colors duration-150"
            aria-label="Switch workspace: {workspace?.name || 'Workspace'}"
            aria-expanded={mobileWorkspaceOpen}
            onclick={() => mobileWorkspaceOpen = !mobileWorkspaceOpen}
          >
            <span class="font-medium truncate">{workspace?.name || 'Workspace'}</span>
            <ChevronDown class="w-4 h-4 text-fg-muted" aria-hidden="true" />
          </button>

          {#if mobileWorkspaceOpen}
            <div class="mt-2 bg-bg-primary border border-bg-tertiary rounded-[10px] overflow-hidden">
              {#each workspaces as ws}
                <button
                  type="button"
                  class="w-full text-left px-4 py-2 text-sm transition-colors duration-150 {ws.id === workspace?.id ? 'bg-bright-purple/20 text-bright-purple' : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
                  onclick={() => switchWorkspace(ws.id)}
                  disabled={ws.id === workspace?.id}
                >
                  {ws.name}
                </button>
              {/each}
            </div>
          {/if}
        </div>

        <nav class="flex-1 p-4 space-y-1" aria-label="Main navigation">
          {#each navItems as item}
            {@const isActive = $page.url === item.href || $page.url.startsWith(item.href + '/')}
            <a
              href={item.href}
              onclick={closeMobileNav}
              class="flex items-center gap-2 px-3 py-2 rounded-[10px] transition-colors duration-150 {isActive ? 'bg-bright-purple/20 text-bright-purple' : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
              aria-current={isActive ? 'page' : undefined}
            >
              <item.icon class="w-4 h-4" aria-hidden="true" />
              <span class="text-sm font-medium">{item.label}</span>
            </a>
          {/each}
        </nav>

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
              <p class="font-medium truncate">{user?.name}</p>
              <p class="text-sm text-fg-muted truncate">{user?.email}</p>
            </div>
          </div>
        </div>
      </aside>
    </div>
  {/if}

  {#if desktopWorkspaceOpen}
    <button
      type="button"
      class="hidden md:block fixed inset-0 z-30 bg-transparent"
      aria-label="Close workspace menu"
      onclick={() => desktopWorkspaceOpen = false}
    ></button>
  {/if}

  <!-- Left Rail -->
  <aside class="hidden md:flex w-64 bg-bg-secondary border-r border-bg-tertiary flex-col" aria-label="Application sidebar">
    <!-- Logo -->
    <div class="p-6 border-b border-bg-tertiary">
      <h1 class="text-2xl font-bold text-bright-purple">Timevoice</h1>
    </div>

    <!-- Workspace Switcher -->
    <div class="p-4 border-b border-bg-tertiary">
      <div class="relative">
        <button
          type="button"
          class="w-full flex items-center justify-between px-4 py-2 bg-bg-tertiary rounded-[10px] hover:bg-bg-quaternary transition-colors duration-150"
          aria-label="Switch workspace: {workspace?.name || 'Workspace'}"
          aria-expanded={desktopWorkspaceOpen}
          onclick={() => desktopWorkspaceOpen = !desktopWorkspaceOpen}
        >
          <span class="font-medium truncate">{workspace?.name || 'Workspace'}</span>
          <ChevronDown class="w-4 h-4 text-fg-muted" aria-hidden="true" />
        </button>

        {#if desktopWorkspaceOpen}
          <div class="absolute top-full left-0 right-0 mt-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden z-40">
            {#each workspaces as ws}
              <button
                type="button"
                class="w-full text-left px-4 py-2 text-sm transition-colors duration-150 {ws.id === workspace?.id ? 'bg-bright-purple/20 text-bright-purple' : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
                onclick={() => switchWorkspace(ws.id)}
                disabled={ws.id === workspace?.id}
              >
                {ws.name}
              </button>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Navigation -->
    <nav class="flex-1 p-4 space-y-1" aria-label="Main navigation">
      {#each navItems as item}
        {@const isActive = $page.url === item.href || $page.url.startsWith(item.href + '/')}
        <a
          href={item.href}
          class="flex items-center gap-2 px-3 py-2 rounded-[10px] transition-colors duration-150 {isActive ? 'bg-bright-purple/20 text-bright-purple' : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
          aria-current={isActive ? 'page' : undefined}
        >
          <item.icon class="w-4 h-4" aria-hidden="true" />
          <span class="text-sm font-medium">{item.label}</span>
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
  <main id="main-content" class="flex-1 flex flex-col min-w-0 pt-14 md:pt-0" tabindex="-1">
    {@render children()}
  </main>
</div>
