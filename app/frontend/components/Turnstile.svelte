<script lang="ts">
  import { page } from "@inertiajs/svelte";

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

  $effect(() => {
    if (!container) return;

    let intervalId: ReturnType<typeof setInterval> | undefined;
    let timeoutId: ReturnType<typeof setTimeout> | undefined;

    const clearTimers = () => {
      if (intervalId) clearInterval(intervalId);
      if (timeoutId) clearTimeout(timeoutId);
    };

    const destroyWidget = () => {
      if (widgetId && window.turnstile) {
        window.turnstile.remove(widgetId);
        widgetId = null;
      }
    };

    const renderWidget = () => {
      if (!window.turnstile || !container || widgetId) return;

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
    };

    destroyWidget();
    renderWidget();

    if (!widgetId) {
      intervalId = setInterval(() => {
        if (window.turnstile) {
          clearTimers();
          renderWidget();
        }
      }, 100);

      timeoutId = setTimeout(clearTimers, 10000);
    }

    return () => {
      clearTimers();
      destroyWidget();
    };
  });
</script>

<div bind:this={container} class="cf-turnstile"></div>
