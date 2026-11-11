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
  // The flexible widget is at least 300px wide; narrow modals on small
  // phones clip it, so fall back to the compact one.
  let narrow = $state(false);

  const siteKey = $derived(
    (page.props.turnstile_site_key as string) || "1x00000000000000000000BB",
  );

  $effect(() => {
    const observer = new ResizeObserver(([entry]) => {
      narrow = entry.contentRect.width < 300;
    });
    observer.observe(container);
    return () => observer.disconnect();
  });

  $effect(() => {
    if (!container) return;
    const widgetSize = size === "flexible" && narrow ? "compact" : size;

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
        size: widgetSize,
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
