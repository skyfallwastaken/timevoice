<script lang="ts">
  import { page, Link } from "@inertiajs/svelte";
  import {
    Clock,
    Calendar,
    FolderKanban,
    BarChart3,
    FileText,
    Building2,
    Tag,
    Settings,
    LogOut,
    ChevronDown,
    Menu,
    X,
    Plus,
    Workflow,
  } from "lucide-svelte";
  import { router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import Modal from "./Modal.svelte";
  import FormField from "./FormField.svelte";
  import TextInput from "./TextInput.svelte";
  import Button from "./Button.svelte";
  import IconButton from "./IconButton.svelte";
  import { fly, fade } from "svelte/transition";
  import { Tween } from "svelte/motion";
  import { quintOut, cubicOut } from "svelte/easing";

  let { children } = $props();

  const user = $derived($page.props.auth?.user);
  const workspace = $derived($page.props.auth?.workspace);
  const isAdmin = $derived($page.props.auth?.is_admin);
  const isDevMode = $derived($page.props.rails_env === "development");

  // Use $state to ensure proper Svelte 5 reactivity with Inertia's page store
  let currentWorkspaceHashid = $state($page.props.auth?.workspace?.hashid || "");
  
  $effect(() => {
    const newHashid = $page.props.auth?.workspace?.hashid || "";
    if (newHashid !== currentWorkspaceHashid) {
      currentWorkspaceHashid = newHashid;
    }
  });

  const navItems = [
    { path: "timer", icon: Clock, label: "Timer" },
    { path: "calendar", icon: Calendar, label: "Calendar" },
    { path: "clients", icon: Building2, label: "Clients" },
    { path: "projects", icon: FolderKanban, label: "Projects" },
    { path: "tags", icon: Tag, label: "Tags" },
    { path: "reports", icon: BarChart3, label: "Reports" },
    { path: "invoices", icon: FileText, label: "Invoices" },
    { path: "settings", icon: Settings, label: "Settings" },
  ];
  const workspaces = $derived($page.props.auth?.workspaces || []);

  let mobileNavOpen = $state(false);
  let mobileWorkspaceOpen = $state(false);
  let desktopWorkspaceOpen = $state(false);
  let showCreateModal = $state(false);

  const activeIndex = $derived(
    navItems.findIndex((item) => {
      const href = `/${currentWorkspaceHashid}/${item.path}`;
      return $page.url === href || $page.url.startsWith(href + "/");
    }),
  );
  const navIndicatorY = new Tween(0, { duration: 140, easing: cubicOut });
  let indicatorInitialized = false;

  $effect(() => {
    const y = activeIndex >= 0 ? activeIndex * 40 : 0;
    if (!indicatorInitialized) {
      indicatorInitialized = true;
      navIndicatorY.set(y, { duration: 0 });
    } else {
      navIndicatorY.target = y;
    }
  });

  let createForm = useForm({
    name: "",
  });

  function signOut() {
    router.delete("/signout");
  }

  function closeMobileNav() {
    mobileNavOpen = false;
    mobileWorkspaceOpen = false;
  }

  function openCreateModal() {
    $createForm.reset();
    showCreateModal = true;
    mobileWorkspaceOpen = false;
    desktopWorkspaceOpen = false;
  }

  function closeCreateModal() {
    showCreateModal = false;
    $createForm.reset();
  }

  function submitCreateWorkspace() {
    $createForm
      .transform((data) => ({ workspace: data }))
      .post("/workspaces", {
        onSuccess: () => {
          closeCreateModal();
        },
      });
  }

  function switchWorkspace(workspaceHashid: string) {
    router.patch(
      "/workspaces/switch",
      { workspace_id: workspaceHashid },
      {
        onSuccess: () => {
          desktopWorkspaceOpen = false;
          mobileWorkspaceOpen = false;
          closeMobileNav();
        },
      },
    );
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "Escape" && mobileNavOpen) closeMobileNav();
  }
</script>

{#snippet navItemsTemplate(onclick?: () => void, animated: boolean = false)}
  <div class="relative space-y-1">
    {#if animated && activeIndex >= 0}
      <span
        class="absolute left-0 right-0 h-9 bg-bright-purple/20 rounded-[10px]"
        style="transform: translateY({navIndicatorY.current}px);"
      ></span>
    {/if}
    {#each navItems as item, index}
      {@const isActive =
        $page.url === `/${currentWorkspaceHashid}/${item.path}` ||
        $page.url.startsWith(`/${currentWorkspaceHashid}/${item.path}/`)}
      <button
        type="button"
        onclick={() => {
          router.visit(`/${currentWorkspaceHashid}/${item.path}`);
          onclick?.();
        }}
        class="w-full relative flex items-center gap-2 px-3 py-2 rounded-[10px] transition-colors duration-150 {isActive
          ? 'text-bright-purple'
          : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
        aria-current={isActive ? "page" : undefined}
      >
        {#if isActive && !animated}
          <span class="absolute inset-0 bg-bright-purple/20 rounded-[10px]"
          ></span>
        {/if}
        <item.icon class="relative w-4 h-4" aria-hidden="true" />
        <span class="relative text-sm font-medium">{item.label}</span>
      </button>
    {/each}
  </div>
{/snippet}

{#snippet userProfile()}
  <div class="flex items-center gap-3 px-4 py-3">
    {#if user?.avatar_url}
      <img src={user.avatar_url} alt="" class="w-10 h-10 rounded-full" />
    {:else}
      <div
        class="w-10 h-10 rounded-full bg-bg-tertiary flex items-center justify-center text-lg font-semibold"
        aria-hidden="true"
      >
        {user?.name?.[0]?.toUpperCase() || "?"}
      </div>
    {/if}
    <div class="flex-1 min-w-0">
      <p class="font-medium truncate">{user?.name}</p>
      <p class="text-sm text-fg-muted truncate">{user?.email}</p>
    </div>
  </div>
{/snippet}

<svelte:window onkeydown={handleKeydown} />

<div class="h-screen bg-bg-primary text-fg-primary flex overflow-hidden">
  {#if isDevMode}
    <div
      class="fixed top-14 md:top-0 left-0 right-0 md:left-64 z-30 bg-yellow-500 text-black text-center text-xs font-bold py-1 px-2"
    >
      DEV MODE
    </div>
  {/if}

  <a href="#main-content" class="skip-link"> Skip to main content </a>

  <header
    class="md:hidden fixed top-0 left-0 right-0 z-30 bg-bg-secondary border-b border-bg-tertiary"
  >
    <div class="h-14 px-4 flex items-center justify-between">
      <IconButton
        onclick={() => (mobileNavOpen = true)}
        aria-label="Open navigation"
      >
        <Menu class="w-5 h-5" aria-hidden="true" />
      </IconButton>

      <div class="min-w-0 text-center">
        <p class="text-sm font-semibold truncate">
          {workspace?.name || "Workspace"}
        </p>
        <p class="text-xs text-fg-muted truncate">{user?.name || ""}</p>
      </div>

      <IconButton
        tone="danger"
        onclick={signOut}
        aria-label="Sign out"
      >
        <LogOut class="w-5 h-5" aria-hidden="true" />
      </IconButton>
    </div>
  </header>

  {#if mobileNavOpen}
    <div class="md:hidden fixed inset-0 z-40" aria-label="Mobile navigation">
      <button
        type="button"
        class="absolute inset-0 bg-black/50"
        onclick={closeMobileNav}
        aria-label="Close navigation"
        transition:fade={{ duration: 200 }}
      ></button>
      <aside
        class="absolute left-0 top-0 bottom-0 w-80 max-w-[85vw] bg-bg-secondary border-r border-bg-tertiary flex flex-col"
        transition:fly={{ x: -300, duration: 300, easing: quintOut }}
      >
        <div
          class="p-4 border-b border-bg-tertiary flex items-center justify-between"
        >
          <h1 class="text-lg font-bold text-bright-purple">Timevoice</h1>
          <IconButton onclick={closeMobileNav} aria-label="Close navigation">
            <X class="w-5 h-5" aria-hidden="true" />
          </IconButton>
        </div>

        <div class="p-4 border-b border-bg-tertiary">
          <button
            type="button"
            class="w-full flex items-center justify-between px-4 py-2 bg-bg-tertiary rounded-[10px] hover:bg-bg-quaternary transition-colors duration-150"
            aria-label="Switch workspace: {workspace?.name || 'Workspace'}"
            aria-expanded={mobileWorkspaceOpen}
            onclick={() => (mobileWorkspaceOpen = !mobileWorkspaceOpen)}
          >
            <span class="font-medium truncate"
              >{workspace?.name || "Workspace"}</span
            >
            <ChevronDown class="w-4 h-4 text-fg-muted" aria-hidden="true" />
          </button>

          {#if mobileWorkspaceOpen}
            <div
              class="mt-2 bg-bg-primary border border-bg-tertiary rounded-[10px] overflow-hidden"
            >
              {#each workspaces as ws}
                <button
                  type="button"
                  class="w-full text-left px-4 py-2 text-sm transition-colors duration-150 {ws.hashid ===
                  workspace?.hashid
                    ? 'bg-bright-purple/20 text-bright-purple'
                    : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
                  onclick={() => switchWorkspace(ws.hashid)}
                  disabled={ws.hashid === workspace?.hashid}
                >
                  {ws.name}
                </button>
              {/each}
              <button
                type="button"
                class="w-full flex items-center gap-2 px-4 py-2 text-sm text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary transition-colors duration-150 border-t border-bg-tertiary"
                onclick={openCreateModal}
              >
                <Plus class="w-4 h-4" />
                Create workspace
              </button>
            </div>
          {/if}
        </div>

        <nav class="flex-1 p-4 space-y-1" aria-label="Main navigation">
          {@render navItemsTemplate(closeMobileNav)}
        </nav>

        {#if isAdmin}
          <div class="px-4 pb-4">
            <div class="admin-tools rounded-lg">
              <p
                class="text-xs font-medium text-fg-dim uppercase tracking-wider px-3 py-2"
              >
                Admin
              </p>
              <a
                href="/admin/jobs"
                onclick={closeMobileNav}
                class="flex items-center gap-2 px-3 py-2 rounded-lg text-amber-500 hover:bg-amber-500/10 transition-colors duration-150"
              >
                <Workflow class="w-4 h-4" aria-hidden="true" />
                <span class="text-sm font-medium">Jobs</span>
              </a>
            </div>
          </div>
        {/if}

        <div class="p-4 border-t border-bg-tertiary">
          {@render userProfile()}
        </div>
      </aside>
    </div>
  {/if}

  {#if desktopWorkspaceOpen}
    <button
      type="button"
      class="hidden md:block fixed inset-0 z-30 bg-transparent"
      aria-label="Close workspace menu"
      onclick={() => (desktopWorkspaceOpen = false)}
    ></button>
  {/if}

  <aside
    class="hidden md:flex w-64 bg-bg-secondary border-r border-bg-tertiary flex-col z-50"
    aria-label="Application sidebar"
  >
    <div class="p-6 border-b border-bg-tertiary">
      <h1 class="text-2xl font-bold text-bright-purple">Timevoice</h1>
    </div>

    <div class="p-4 border-b border-bg-tertiary">
      <div class="relative">
        <button
          type="button"
          class="w-full flex items-center justify-between px-4 py-2 bg-bg-tertiary rounded-[10px] hover:bg-bg-quaternary transition-colors duration-150"
          aria-label="Switch workspace: {workspace?.name || 'Workspace'}"
          aria-expanded={desktopWorkspaceOpen}
          onclick={() => (desktopWorkspaceOpen = !desktopWorkspaceOpen)}
        >
          <span class="font-medium truncate"
            >{workspace?.name || "Workspace"}</span
          >
          <ChevronDown class="w-4 h-4 text-fg-muted" aria-hidden="true" />
        </button>

        {#if desktopWorkspaceOpen}
          <div
            class="absolute top-full left-0 right-0 mt-2 bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden z-40"
          >
            {#each workspaces as ws}
              <button
                type="button"
                class="w-full text-left px-4 py-2 text-sm transition-colors duration-150 {ws.hashid ===
                workspace?.hashid
                  ? 'bg-bright-purple/20 text-bright-purple'
                  : 'text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary'}"
                onclick={() => switchWorkspace(ws.hashid)}
                disabled={ws.hashid === workspace?.hashid}
              >
                {ws.name}
              </button>
            {/each}
            <button
              type="button"
              class="w-full flex items-center gap-2 px-4 py-2 text-sm text-fg-secondary hover:bg-bg-tertiary hover:text-fg-primary transition-colors duration-150 border-t border-bg-tertiary"
              onclick={openCreateModal}
            >
              <Plus class="w-4 h-4" />
              Create workspace
            </button>
          </div>
        {/if}
      </div>
    </div>

    <nav class="flex-1 p-4" aria-label="Main navigation">
      {@render navItemsTemplate(undefined, true)}
    </nav>

    {#if isAdmin}
      <div class="px-4 pb-4">
        <div class="admin-tools rounded-lg">
          <p
            class="text-xs font-medium text-fg-dim uppercase tracking-wider px-3 py-2"
          >
            Admin
          </p>
          <a
            href="/admin/jobs"
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-amber-500 hover:bg-amber-500/10 transition-colors duration-150"
          >
            <Workflow class="w-4 h-4" aria-hidden="true" />
            <span class="text-sm font-medium">Jobs</span>
          </a>
        </div>
      </div>
    {/if}

    <div class="p-4 border-t border-bg-tertiary">
      {@render userProfile()}
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

  <main
    id="main-content"
    class="flex-1 flex flex-col min-w-0 pt-[calc(3.5rem+var(--dev-banner-h))] md:pt-(--dev-banner-h)"
    style="--dev-banner-h: {isDevMode ? '1.5rem' : '0px'}"
    tabindex="-1"
  >
    {@render children()}
  </main>

  <Modal
    bind:open={showCreateModal}
    title="Create Workspace"
    onclose={closeCreateModal}
  >
    <FormField
      id="workspace-name"
      label="Workspace Name"
      error={$createForm.errors?.name}
    >
      {#snippet children({ describedBy })}
        <TextInput
          id="workspace-name"
          tone="purple"
          bind:value={$createForm.name}
          placeholder="My Team"
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          variant="ghost"
          onclick={closeCreateModal}
          disabled={$createForm.processing}
        >
          Cancel
        </Button>
        <Button
          tone="purple"
          onclick={submitCreateWorkspace}
          disabled={$createForm.processing || !$createForm.name}
        >
          {$createForm.processing ? "Creating..." : "Create Workspace"}
        </Button>
      </div>
    {/snippet}
  </Modal>
</div>
