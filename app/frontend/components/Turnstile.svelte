<script module lang="ts">
  // Only the invite and invoice email forms use Turnstile, so its script loads
  // the first time a widget mounts instead of on every page.
  type TurnstileApi = NonNullable<Window["turnstile"]>;
  let loading: Promise<TurnstileApi> | undefined;

  function loadTurnstile(): Promise<TurnstileApi> {
    if (window.turnstile) return Promise.resolve(window.turnstile);
    loading ??= new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src =
        "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      script.async = true;
      script.onload = () =>
        window.turnstile ? resolve(window.turnstile) : reject();
      script.onerror = () => {
        script.remove();
        loading = undefined;
        reject();
      };
      document.head.append(script);
    });
    return loading;
  }
</script>

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
    const options = {
      sitekey: siteKey,
      theme,
      size: size === "flexible" && narrow ? "compact" : size,
    };
    let cancelled = false;

    loadTurnstile().then(
      (turnstile) => {
        if (cancelled) return;
        widgetId = turnstile.render(container, {
          ...options,
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
      },
      () => {
        if (!cancelled) onError?.();
      },
    );

    return () => {
      cancelled = true;
      if (widgetId && window.turnstile) {
        window.turnstile.remove(widgetId);
        widgetId = null;
      }
    };
  });
</script>

<div bind:this={container} class="cf-turnstile"></div>
