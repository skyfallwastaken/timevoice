<script lang="ts">
  import { page } from "@inertiajs/svelte";
  import { onMount, onDestroy } from "svelte";

  interface Props {
    onSuccess?: (token: string) => void;
    onError?: () => void;
    onExpire?: () => void;
    theme?: "light" | "dark" | "auto";
    size?: "normal" | "compact" | "flexible";
  }

  let {
    onSuccess,
    onError,
    onExpire,
    theme = "dark",
    size = "flexible",
  }: Props = $props();

  let container: HTMLDivElement;
  let widgetId: string | null = null;

  const siteKey = $derived(
    ($page.props.turnstile_site_key as string) || "1x00000000000000000000BB",
  );

  onMount(() => {
    const renderWidget = () => {
      if (window.turnstile && container && !widgetId) {
        widgetId = window.turnstile.render(container, {
          sitekey: siteKey,
          theme,
          size,
          callback: (token: string) => {
            onSuccess?.(token);
          },
          "error-callback": () => {
            onError?.();
          },
          "expired-callback": () => {
            onExpire?.();
          },
        });
      }
    };

    if (window.turnstile) {
      renderWidget();
    } else {
      const interval = setInterval(() => {
        if (window.turnstile) {
          clearInterval(interval);
          renderWidget();
        }
      }, 100);

      setTimeout(() => clearInterval(interval), 10000);
    }
  });

  onDestroy(() => {
    if (widgetId && window.turnstile) {
      window.turnstile.remove(widgetId);
    }
  });
</script>

<div bind:this={container} class="cf-turnstile"></div>
