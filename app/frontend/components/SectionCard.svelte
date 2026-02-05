<script lang="ts">
  interface Props {
    title?: string;
    description?: string;
    icon?: any;
    iconColor?: string;
    headerActions?: import("svelte").Snippet;
    header?: import("svelte").Snippet;
    headerless?: boolean;
    footer?: import("svelte").Snippet;
    bodyClass?: string;
    headerClass?: string;
    class?: string;
    children: import("svelte").Snippet;
  }

  let {
    title,
    description,
    icon: Icon,
    iconColor = "text-fg-muted",
    headerActions,
    header,
    headerless = false,
    footer,
    bodyClass = "",
    headerClass = "p-4 border-b border-bg-tertiary",
    class: className = "",
    children,
    ...rest
  }: Props = $props();
</script>

<div
  class="bg-bg-secondary border border-bg-tertiary rounded-[10px] {className}"
  {...rest}
>
  {#if !headerless && (header || title || description || headerActions)}
    <div class="{headerClass}">
      {#if header}
        {@render header()}
      {:else}
        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center gap-2 min-w-0">
            {#if Icon}
              <Icon class="w-5 h-5 {iconColor}" aria-hidden="true" />
            {/if}
            <div class="min-w-0">
              {#if title}
                <h3 class="font-semibold truncate">{title}</h3>
              {/if}
              {#if description}
                <p class="text-sm text-fg-muted mt-1">{description}</p>
              {/if}
            </div>
          </div>
          {#if headerActions}
            <div class="flex items-center gap-2">
              {@render headerActions()}
            </div>
          {/if}
        </div>
      {/if}
    </div>
  {/if}

  <div class="{bodyClass}">
    {@render children()}
  </div>

  {#if footer}
    <div class="p-4 border-t border-bg-tertiary">
      {@render footer()}
    </div>
  {/if}
</div>
