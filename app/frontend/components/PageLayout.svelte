<script lang="ts">
  import Flash from "./Flash.svelte";

  interface Props {
    title: string;
    icon?: any;
    iconColor?: string;
    variant?: "wide" | "narrow";
    flash?: { notice?: string; alert?: string };
    children: import("svelte").Snippet;
    headerActions?: import("svelte").Snippet;
  }

  let {
    title,
    icon: IconComponent,
    iconColor = "text-bright-blue",
    variant = "narrow",
    flash,
    children,
    headerActions,
  }: Props = $props();
</script>

<div class="flex-1 p-4 sm:p-6 overflow-auto">
  <div
    class="{variant === 'wide' ? 'max-w-6xl' : 'max-w-4xl'} mx-auto space-y-6"
  >
    <div
      class="flex flex-col sm:flex-row sm:items-center justify-between gap-3"
    >
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

    <Flash {flash} />

    {@render children()}
  </div>
</div>
