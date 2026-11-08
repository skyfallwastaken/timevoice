<script lang="ts">
  import { DropdownMenu as DropdownMenuPrimitive } from "bits-ui";
  import { cn, type WithoutChildrenOrChild } from "$lib/utils.js";
  import DropdownMenuPortal from "./dropdown-menu-portal.svelte";
  import type { ComponentProps } from "svelte";

  let {
    ref = $bindable(null),
    sideOffset = 4,
    align = "start",
    portalProps,
    class: className,
    ...restProps
  }: DropdownMenuPrimitive.ContentProps & {
    portalProps?: WithoutChildrenOrChild<
      ComponentProps<typeof DropdownMenuPortal>
    >;
  } = $props();
</script>

<DropdownMenuPortal {...portalProps}>
  <DropdownMenuPrimitive.Content
    bind:ref
    data-slot="dropdown-menu-content"
    {sideOffset}
    {align}
    class={cn(
      "data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-97 data-open:zoom-in-97 data-[side=bottom]:slide-in-from-top-1 data-[side=left]:slide-in-from-right-1 data-[side=right]:slide-in-from-left-1 data-[side=top]:slide-in-from-bottom-1 duration-120 ease-out data-closed:duration-75 data-closed:ease-in border border-border bg-popover text-popover-foreground min-w-32 rounded-[10px] p-1 shadow-[inset_0_1px_0_rgb(255_255_255/0.05),0_2px_6px_-1px_rgb(0_0_0/0.2),0_16px_36px_-8px_rgb(0_0_0/0.45)]! z-50 max-h-(--bits-dropdown-menu-content-available-height) w-(--bits-dropdown-menu-anchor-width) origin-(--bits-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto data-closed:overflow-hidden",
      className,
    )}
    {...restProps}
  />
</DropdownMenuPortal>
