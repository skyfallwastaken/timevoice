<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import SettingsTabs from "../../components/SettingsTabs.svelte";
  import { page, router } from "@inertiajs/svelte";
  import { Settings, Check } from "@lucide/svelte";
  import { routes } from "../../lib/routes";
  import { applyTheme } from "../../lib/theme";

  type Theme = {
    key: string;
    name: string;
    family: string;
    mode: "dark" | "light";
  };

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);
  let themes = $derived((page.props.themes as Theme[]) || []);
  let selected = $state(page.props.currentTheme as string);

  let families = $derived(
    [...new Set(themes.map((t) => t.family))].map((family) => ({
      family,
      themes: themes.filter((t) => t.family === family),
    })),
  );

  const accents = [
    "bg-bright-red",
    "bg-bright-orange",
    "bg-bright-yellow",
    "bg-bright-green",
    "bg-bright-aqua",
    "bg-bright-blue",
    "bg-bright-purple",
  ];

  function choose(theme: Theme) {
    if (theme.key === selected) return;
    const previous = themes.find((t) => t.key === selected);
    selected = theme.key;
    applyTheme(theme.key, theme.mode);
    router.patch(
      routes.settings.themes(workspaceId),
      { theme: theme.key },
      {
        preserveScroll: true,
        preserveState: true,
        onError: () => {
          if (!previous) return;
          selected = previous.key;
          applyTheme(previous.key, previous.mode);
        },
      },
    );
  }
</script>

<PageLayout title="Settings" icon={Settings}>
  <SectionCard class="overflow-hidden" bodyClass="p-0">
    <SettingsTabs {workspaceId} active="themes" />
  </SectionCard>

  <p class="text-sm text-fg-muted">
    Your theme follows your account on every device. It only changes how
    Timevoice looks for you.
  </p>

  {#each families as group (group.family)}
    <section aria-labelledby="family-{group.family}">
      <h3
        id="family-{group.family}"
        class="text-sm font-semibold text-fg-secondary mb-3"
      >
        {group.family}
      </h3>
      <div
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
        role="radiogroup"
        aria-labelledby="family-{group.family}"
      >
        {#each group.themes as theme (theme.key)}
          {@const isSelected = theme.key === selected}
          <button
            type="button"
            role="radio"
            aria-checked={isSelected}
            onclick={() => choose(theme)}
            class="rounded-[12px] border-2 overflow-hidden bg-bg-secondary text-left transition-colors duration-150 {isSelected
              ? 'border-bright-purple'
              : 'border-bg-tertiary hover:border-bg-quaternary'}"
          >
            <div
              data-theme={theme.key}
              data-mode={theme.mode}
              class="overflow-hidden bg-bg-primary border-b border-bg-tertiary"
              aria-hidden="true"
            >
              <div class="flex h-24">
                <div
                  class="w-1/4 bg-bg-secondary border-r border-bg-tertiary p-2 space-y-1.5"
                >
                  <div class="h-1.5 w-3/4 rounded-full bg-bright-purple"></div>
                  <div class="h-3 rounded bg-bright-purple/20"></div>
                  <div class="h-1.5 w-2/3 rounded-full bg-fg-dim/50"></div>
                  <div class="h-1.5 w-1/2 rounded-full bg-fg-dim/50"></div>
                </div>
                <div class="flex-1 p-2 space-y-2 min-w-0">
                  <div
                    class="flex items-center gap-1.5 rounded-[4px] bg-bg-secondary border border-bg-tertiary px-2 py-1.5"
                  >
                    <span class="text-xs font-semibold text-fg-primary">Aa</span
                    >
                    <span class="text-[10px] text-fg-muted truncate"
                      >Sprint planning</span
                    >
                    <span
                      class="ml-auto size-3.5 shrink-0 rounded-full bg-bright-purple"
                    ></span>
                  </div>
                  <div class="flex gap-1">
                    {#each accents as accent}
                      <span class="size-3 rounded-full {accent}"></span>
                    {/each}
                  </div>
                  <div
                    class="h-3 w-2/3 rounded bg-bright-green/20 border border-bright-green/40"
                  ></div>
                </div>
              </div>
            </div>
            <div class="flex items-center justify-between px-3 py-2">
              <span class="text-sm font-medium text-fg-primary"
                >{theme.name}</span
              >
              {#if isSelected}
                <Check class="w-4 h-4 text-bright-purple" aria-hidden="true" />
              {:else}
                <span class="text-xs text-fg-muted capitalize"
                  >{theme.mode}</span
                >
              {/if}
            </div>
          </button>
        {/each}
      </div>
    </section>
  {/each}
</PageLayout>
