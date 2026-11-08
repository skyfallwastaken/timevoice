<script lang="ts">
  import { Toaster as Sonner, type ToasterProps } from "svelte-sonner";
  import { CircleAlert, CircleCheck } from "@lucide/svelte";

  let { ...restProps }: ToasterProps = $props();
</script>

<!-- Thin pills, centred above the bottom edge; sonner still handles stacking,
     timing, swipe-to-dismiss, and enter/exit motion. -->
<Sonner
  position="bottom-center"
  duration={3500}
  gap={8}
  offset={20}
  mobileOffset={16}
  toastOptions={{
    unstyled: true,
    classes: {
      toast:
        "inset-x-0 mx-auto w-fit max-w-[calc(100vw-2rem)] flex items-center gap-2 min-h-9 pl-3 pr-4 py-1.5 rounded-full border border-bg-quaternary/60 bg-bg-tertiary text-fg-primary font-sans text-sm font-medium shadow-[0_1px_2px_rgb(0_0_0/0.16),0_8px_24px_-6px_rgb(0_0_0/0.35)]",
      icon: "flex shrink-0 [&_svg]:size-4",
      content: "min-w-0",
    },
  }}
  {...restProps}
>
  {#snippet successIcon()}
    <CircleCheck class="text-bright-green" aria-hidden="true" />
  {/snippet}
  {#snippet errorIcon()}
    <CircleAlert class="text-bright-red" aria-hidden="true" />
  {/snippet}
</Sonner>
