<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import { routes } from "../lib/routes";

  interface Props {
    workspaceId: string;
    active: "workspace" | "billing" | "developer";
  }

  let { workspaceId, active }: Props = $props();

  const tabs = [
    { key: "workspace", label: "Workspace", href: routes.settings.workspace },
    { key: "billing", label: "Billing", href: routes.settings.billing },
    { key: "developer", label: "Developer", href: routes.settings.developer },
  ] as const;
</script>

<div class="grid grid-cols-3">
  {#each tabs as tab, index}
    <Link
      href={tab.href(workspaceId)}
      class="px-4 py-2 text-sm font-medium transition-colors duration-150 {active ===
      tab.key
        ? 'bg-bg-tertiary text-fg-primary'
        : 'text-fg-secondary hover:bg-bg-tertiary'} {index < tabs.length - 1
        ? 'border-r border-bg-tertiary'
        : ''}"
      aria-current={active === tab.key ? "page" : undefined}
    >
      {tab.label}
    </Link>
  {/each}
</div>
