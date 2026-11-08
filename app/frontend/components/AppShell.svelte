<script lang="ts">
  import { page, Link, router } from "@inertiajs/svelte";
  import {
    Clock,
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
    Square,
  } from "@lucide/svelte";
  import { useForm } from "@inertiajs/svelte";
  import Modal from "./Modal.svelte";
  import FormField from "./FormField.svelte";
  import TextInput from "./TextInput.svelte";
  import Button from "./Button.svelte";
  import IconButton from "./IconButton.svelte";
  import { fly, fade } from "svelte/transition";
  import { untrack } from "svelte";
  import { Tween } from "svelte/motion";
  import { quintOut, cubicOut } from "svelte/easing";
  import { routes } from "../lib/routes";
  import { formatDuration } from "../lib/format";
  import type { RunningEntry } from "../types";
  import * as DropdownMenu from "$lib/components/ui/dropdown-menu/index.js";
  import { Toaster } from "$lib/components/ui/sonner/index.js";
  import { toast } from "svelte-sonner";

  let { children } = $props();

  const user = $derived(page.props.auth?.user);
  const workspace = $derived(page.props.auth?.workspace);
  const isAdmin = $derived(page.props.auth?.is_admin);
  const isDevMode = $derived(page.props.rails_env === "development");

  const currentWorkspaceHashid = $derived(
    page.props.auth?.workspace?.hashid || "",
  );

  const navItems = [
    {
      href: routes.dashboard.index,
      icon: Clock,
      label: "Timer",
      component: "Dashboard/Index",
    },
    {
      href: routes.clients.index,
      icon: Building2,
      label: "Clients",
      component: "Clients/Index",
    },
    {
      href: routes.projects.index,
      icon: FolderKanban,
      label: "Projects",
      component: "Projects/Index",
    },
    {
      href: routes.tags.index,
      icon: Tag,
      label: "Tags",
      component: "Tags/Index",
    },
    {
      href: routes.reports.index,
      icon: BarChart3,
      label: "Reports",
      component: "Reports/Index",
    },
    {
      href: routes.invoices.index,
      icon: FileText,
      label: "Invoices",
      component: "Invoices/Index",
    },
    {
      href: routes.settings.index,
      icon: Settings,
      label: "Settings",
      component: "Settings/Workspace",
    },
  ];

  // The latest props of each sidebar page, by URL. A nav link with cached
  // props is an instant visit: it renders the page from the cache at once
  // while the visit fetches fresh props. Pages without cached props yet use a
  // regular visit.
  const pageCache: Record<string, Record<string, unknown>> = $state({});
  // When each entry was stored, so a slow refresh can't replace newer props.
  const cachedAt = new Map<string, number>();

  function cache(url: string, props: Record<string, unknown>, at: number) {
    if ((cachedAt.get(url) ?? 0) > at) return;
    cachedAt.set(url, at);
    pageCache[url] = props;
  }

  const instantPageProps =
    (href: string) => (_: unknown, shared: Record<string, unknown>) => ({
      ...pageCache[href],
      ...shared,
      flash: {},
    });

  // Fetches each sidebar page's props the way an Inertia visit would,
  // without touching the current page or Inertia's prefetch cache.
  function refreshPageCache(hrefs: string[]) {
    for (const href of hrefs) {
      const startedAt = performance.now();
      if (href === page.url) {
        cache(href, page.props, startedAt);
        continue;
      }
      fetch(href, {
        headers: {
          "X-Inertia": "true",
          "X-Inertia-Version": page.version ?? "",
          Purpose: "prefetch",
        },
      })
        .then((response) =>
          response.ok && response.headers.has("X-Inertia")
            ? response.json()
            : null,
        )
        .then((fetched) => {
          if (fetched?.props) cache(href, fetched.props, startedAt);
        })
        .catch(() => {});
    }
  }

  // Refill the cache on load, on switching workspace, and every minute.
  $effect(() => {
    const hrefs = navItems.map((item) => item.href(currentWorkspaceHashid));
    untrack(() => {
      for (const url of Object.keys(pageCache)) delete pageCache[url];
      cachedAt.clear();
    });

    // "success" fires for every response, including redirects back to the
    // same page after a change and the request behind an instant visit;
    // "navigate" misses those and fires for renders from this cache.
    const stopSuccess = router.on("success", (event) => {
      const { url, props } = event.detail.page;
      if (hrefs.includes(url)) {
        cache(url, props, performance.now());
        return;
      }
      // A change made on a filtered or nested URL (?view=…, /invoices/:id)
      // can change the sidebar page's props too.
      const href = hrefs.find(
        (h) => url.startsWith(`${h}?`) || url.startsWith(`${h}/`),
      );
      if (href) untrack(() => refreshPageCache([href]));
    });
    const refresh = () => untrack(() => refreshPageCache(hrefs));
    refresh();
    const timer = setInterval(() => {
      if (document.visibilityState === "visible") refresh();
    }, 60_000);
    return () => {
      stopSuccess();
      clearInterval(timer);
    };
  });

  const workspaces = $derived(page.props.auth?.workspaces || []);

  // The running timer, shown in the tab title on every page and in the
  // sidebar and mobile header off the Timer page, which has its own.
  const runningEntry = $derived(
    (page.props.runningEntry as RunningEntry | null | undefined) ?? null,
  );
  const showRunningTimer = $derived(
    !!runningEntry && page.component !== "Dashboard/Index",
  );
  let now = $state(Date.now());
  $effect(() => {
    if (!runningEntry) return;
    now = Date.now();
    const interval = setInterval(() => (now = Date.now()), 1000);
    return () => clearInterval(interval);
  });
  const runningElapsed = $derived(
    runningEntry
      ? formatDuration(
          Math.max(
            0,
            Math.floor(
              (now - new Date(runningEntry.start_at).getTime()) / 1000,
            ),
          ),
        )
      : "",
  );
  $effect(() => {
    document.title = runningEntry
      ? `${[runningElapsed, runningEntry.description].filter(Boolean).join(" · ")} – Timevoice`
      : "Timevoice";
  });

  let stopping = $state(false);
  function stopRunningTimer() {
    if (!runningEntry || stopping) return;
    stopping = true;
    router.patch(
      routes.timeEntries.stop(currentWorkspaceHashid, runningEntry.id),
      {},
      { preserveScroll: true, onFinish: () => (stopping = false) },
    );
  }

  let mobileNavOpen = $state(false);
  let showCreateModal = $state(false);

  // Inertia fires this once per response that carries a flash message.
  $effect(() =>
    router.on("flash", (event) => {
      const { notice, alert } = event.detail.flash;
      if (notice) toast.success(notice);
      if (alert) toast.error(alert);
    }),
  );

  const activeIndex = $derived.by(() => {
    const path = page.url.split("?")[0];
    if (path === `/${currentWorkspaceHashid}`) return 0;
    return navItems.findIndex((item) => {
      const href = item.href(currentWorkspaceHashid);
      return path === href || path.startsWith(href + "/");
    });
  });
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

  function closeMobileNav() {
    mobileNavOpen = false;
  }

  function signOut() {
    router.delete(routes.auth.logout);
  }

  function openCreateModal() {
    createForm.reset();
    showCreateModal = true;
  }

  function closeCreateModal() {
    showCreateModal = false;
  }

  function submitCreateWorkspace() {
    createForm
      .transform((data) => ({ workspace: data }))
      .post(routes.workspaces.create, {
        onSuccess: () => {
          closeCreateModal();
          // Keep the blank defaults the next open resets to; Inertia otherwise
          // adopts the submitted values as the new defaults.
          createForm.defaults({});
        },
      });
  }

  function switchWorkspace(workspaceHashid: string) {
    if (workspaceHashid === workspace?.hashid) return;
    router.patch(
      routes.workspaces.switch,
      { workspace_id: workspaceHashid },
      { onSuccess: closeMobileNav },
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
    {#each navItems as item}
      {@const href = item.href(currentWorkspaceHashid)}
      {@const isActive = page.url === href || page.url.startsWith(href + "/")}
      <Link
        {href}
        component={pageCache[href] ? item.component : undefined}
        pageProps={instantPageProps(href)}
        {onclick}
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
      </Link>
    {/each}
  </div>
{/snippet}

{#snippet workspaceSwitcher()}
  <DropdownMenu.Root>
    <DropdownMenu.Trigger
      class="group w-full flex items-center justify-between px-3 py-2 text-sm bg-bg-tertiary rounded-[10px] hover:bg-bg-quaternary data-[state=open]:bg-bg-quaternary transition-colors duration-150"
      aria-label="Switch workspace: {workspace?.name || 'Workspace'}"
    >
      <span class="font-medium truncate">{workspace?.name || "Workspace"}</span>
      <ChevronDown
        class="w-4 h-4 text-fg-muted transition-transform duration-150 group-data-[state=open]:rotate-180"
        aria-hidden="true"
      />
    </DropdownMenu.Trigger>
    <DropdownMenu.Content sideOffset={6}>
      <DropdownMenu.Label class="px-2">Workspaces</DropdownMenu.Label>
      <DropdownMenu.RadioGroup
        value={workspace?.hashid}
        onValueChange={switchWorkspace}
      >
        {#each workspaces as ws (ws.hashid)}
          <DropdownMenu.RadioItem
            value={ws.hashid}
            closeOnSelect
            class="px-2 py-1.5 rounded-[6px] data-[state=checked]:text-bright-purple"
          >
            <span class="truncate">{ws.name}</span>
          </DropdownMenu.RadioItem>
        {/each}
      </DropdownMenu.RadioGroup>
      <DropdownMenu.Separator />
      <DropdownMenu.Item
        class="px-2 py-1.5 gap-2 rounded-[6px] text-fg-secondary"
        onSelect={openCreateModal}
      >
        <Plus aria-hidden="true" /> Create workspace
      </DropdownMenu.Item>
    </DropdownMenu.Content>
  </DropdownMenu.Root>
{/snippet}

{#snippet runningTimer()}
  {#if runningEntry}
    <div
      class="flex items-center gap-2 p-2 pl-3 rounded-[10px] bg-bg-tertiary"
      data-running-timer
    >
      <Link
        href={routes.dashboard.index(currentWorkspaceHashid)}
        class="flex-1 min-w-0 rounded-[6px] focus-visible:ring-2 focus-visible:ring-bright-blue"
        aria-label="Running timer: {runningEntry.description ||
          'No description'}, {runningElapsed}"
      >
        <p class="flex items-center gap-1.5 text-sm font-medium min-w-0">
          <span
            class="size-2 shrink-0 rounded-full {runningEntry.project
              ? ''
              : 'bg-fg-dim'}"
            style={runningEntry.project
              ? `background-color: ${runningEntry.project.color}`
              : undefined}
            aria-hidden="true"
          ></span>
          <span
            class="truncate {runningEntry.description ? '' : 'text-fg-muted'}"
            >{runningEntry.description || "No description"}</span
          >
        </p>
        <p class="flex items-center gap-1.5 text-xs text-fg-muted min-w-0">
          <span class="font-tabular text-fg-primary">{runningElapsed}</span>
          {#if runningEntry.project}
            <span class="truncate">· {runningEntry.project.name}</span>
          {/if}
        </p>
      </Link>
      <button
        type="button"
        onclick={stopRunningTimer}
        disabled={stopping}
        class="size-8 shrink-0 grid place-items-center rounded-full bg-bright-red hover:bg-accent-red text-bg-primary transition-colors duration-150 disabled:opacity-50"
        aria-label="Stop timer"
        title="Stop timer"
      >
        <Square class="size-3 fill-current" aria-hidden="true" />
      </button>
    </div>
  {/if}
{/snippet}

{#snippet userProfile()}
  <div class="flex items-center gap-3 px-3 py-2">
    {#if user?.avatar_url}
      <img src={user.avatar_url} alt="" class="w-8 h-8 rounded-full" />
    {:else}
      <div
        class="w-8 h-8 rounded-full bg-bg-tertiary flex items-center justify-center text-sm font-medium"
        aria-hidden="true"
      >
        {user?.name?.[0]?.toUpperCase() || "?"}
      </div>
    {/if}
    <div class="flex-1 min-w-0">
      <p class="text-sm font-medium truncate">{user?.name}</p>
      <p class="text-sm text-fg-muted truncate">{user?.email}</p>
    </div>
  </div>
  <button
    type="button"
    onclick={signOut}
    class="w-full flex items-center gap-2 px-3 py-2 mt-2 text-sm font-medium text-fg-muted hover:text-bright-red transition-colors duration-150 rounded-[10px] focus-visible:ring-2 focus-visible:ring-bright-blue"
    aria-label="Sign out {user?.name}"
  >
    <LogOut class="w-4 h-4" aria-hidden="true" />
    <span>Sign out</span>
  </button>
{/snippet}

<svelte:window onkeydown={handleKeydown} />

<div class="h-screen bg-bg-primary text-fg-primary flex overflow-hidden">
  {#if isDevMode}
    <div
      class="fixed top-14 md:top-0 left-0 right-0 md:left-64 z-30 bg-yellow-500 text-black text-center text-xs font-semibold py-1 px-2"
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

      {#if showRunningTimer && runningEntry}
        <Link
          href={routes.dashboard.index(currentWorkspaceHashid)}
          class="flex-1 min-w-0 px-3 text-center"
          aria-label="Running timer: {runningEntry.description ||
            'No description'}, {runningElapsed}"
          data-running-timer
        >
          <p
            class="flex items-center justify-center gap-1.5 text-sm font-semibold font-tabular"
          >
            <span
              class="size-2 shrink-0 rounded-full {runningEntry.project
                ? ''
                : 'bg-fg-dim'}"
              style={runningEntry.project
                ? `background-color: ${runningEntry.project.color}`
                : undefined}
              aria-hidden="true"
            ></span>
            {runningElapsed}
          </p>
          <p class="text-xs text-fg-muted truncate">
            {runningEntry.description || "No description"}
          </p>
        </Link>
        <button
          type="button"
          onclick={stopRunningTimer}
          disabled={stopping}
          class="size-9 shrink-0 grid place-items-center rounded-full bg-bright-red hover:bg-accent-red text-bg-primary transition-colors duration-150 disabled:opacity-50"
          aria-label="Stop timer"
        >
          <Square class="size-3.5 fill-current" aria-hidden="true" />
        </button>
      {:else}
        <div class="min-w-0 text-center">
          <p class="text-sm font-semibold truncate">
            {workspace?.name || "Workspace"}
          </p>
          <p class="text-xs text-fg-muted truncate">{user?.name || ""}</p>
        </div>

        <div class="w-9 shrink-0" aria-hidden="true"></div>
      {/if}
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
          <h1 class="text-lg font-semibold tracking-tight text-bright-purple">
            Timevoice
          </h1>
          <IconButton onclick={closeMobileNav} aria-label="Close navigation">
            <X class="w-5 h-5" aria-hidden="true" />
          </IconButton>
        </div>

        <div class="p-4 border-b border-bg-tertiary">
          {@render workspaceSwitcher()}
        </div>

        <nav class="flex-1 p-4 space-y-1" aria-label="Main navigation">
          {@render navItemsTemplate(closeMobileNav)}
        </nav>

        {#if isAdmin}
          <div class="px-4 pb-4">
            <div class="admin-tools rounded-lg">
              <p
                class="text-xs font-medium text-fg-muted uppercase tracking-wider px-3 py-2"
              >
                Admin
              </p>
              <a
                href={routes.admin.jobs}
                onclick={closeMobileNav}
                class="flex items-center gap-2 px-3 py-2 rounded-lg text-bright-yellow hover:bg-bright-yellow/10 transition-colors duration-150"
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

  <aside
    class="hidden md:flex w-64 bg-bg-secondary border-r border-bg-tertiary flex-col z-50"
    aria-label="Application sidebar"
  >
    <div class="p-6 border-b border-bg-tertiary">
      <h1 class="text-xl font-semibold tracking-tight text-bright-purple">
        Timevoice
      </h1>
    </div>

    <div class="p-4 border-b border-bg-tertiary">
      {@render workspaceSwitcher()}
    </div>

    <nav class="flex-1 p-4" aria-label="Main navigation">
      {@render navItemsTemplate(undefined, true)}
    </nav>

    {#if isAdmin}
      <div class="px-4 pb-4">
        <div class="admin-tools rounded-lg">
          <p
            class="text-xs font-medium text-fg-muted uppercase tracking-wider px-3 py-2"
          >
            Admin
          </p>
          <a
            href={routes.admin.jobs}
            class="flex items-center gap-2 px-3 py-2 rounded-lg text-bright-yellow hover:bg-bright-yellow/10 transition-colors duration-150"
          >
            <Workflow class="w-4 h-4" aria-hidden="true" />
            <span class="text-sm font-medium">Jobs</span>
          </a>
        </div>
      </div>
    {/if}

    {#if showRunningTimer}
      <div class="px-4 pb-4">
        {@render runningTimer()}
      </div>
    {/if}

    <div class="p-4 border-t border-bg-tertiary">
      {@render userProfile()}
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

  <Toaster />

  <Modal
    bind:open={showCreateModal}
    title="Create Workspace"
    onclose={closeCreateModal}
  >
    <FormField
      id="workspace-name"
      label="Workspace Name"
      error={createForm.errors?.name}
    >
      {#snippet children({ describedBy })}
        <TextInput
          id="workspace-name"
          tone="purple"
          bind:value={createForm.name}
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
          disabled={createForm.processing}
        >
          Cancel
        </Button>
        <Button
          tone="purple"
          onclick={submitCreateWorkspace}
          disabled={createForm.processing || !createForm.name}
        >
          {createForm.processing ? "Creating..." : "Create Workspace"}
        </Button>
      </div>
    {/snippet}
  </Modal>
</div>
