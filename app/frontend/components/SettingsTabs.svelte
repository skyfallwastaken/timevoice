<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import { routes } from "../lib/routes";

  interface Props {
    workspaceId: string;
    active: "workspace" | "billing" | "developer" | "themes";
  }

  let { workspaceId, active }: Props = $props();

  const tabs = [
    { key: "workspace", label: "Workspace", href: routes.settings.workspace },
    { key: "billing", label: "Billing", href: routes.settings.billing },
    { key: "developer", label: "Developer", href: routes.settings.developer },
    { key: "themes", label: "Appearance", href: routes.settings.themes },
  ] as const;
</script>

<!-- Two rows on narrow phones, where the four tabs don't fit in one. -->
<div class="grid grid-cols-2 sm:flex select-none">
  {#each tabs as tab, index}
    <Link
      href={tab.href(workspaceId)}
      class="flex-1 px-3 sm:px-4 py-2 text-sm font-medium text-center whitespace-nowrap transition-colors duration-150 {active ===
      tab.key
        ? 'bg-bg-tertiary text-fg-primary'
        : 'text-fg-secondary hover:bg-bg-tertiary'} border-bg-tertiary {index <
      2
        ? 'max-sm:border-b'
        : ''} {index % 2 === 0 ? 'border-r' : ''} {index === 1
        ? 'sm:border-r'
        : ''}"
      aria-current={active === tab.key ? "page" : undefined}
    >
      {tab.label}
    </Link>
  {/each}
</div>
