import "../assets/tailwind.css";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import { mount } from "svelte";
import AppShell from "../components/AppShell.svelte";
import { syncThemeColor } from "../lib/theme";

// The server reads this to bucket entries into days in the browser's timezone.
document.cookie = `tz=${encodeURIComponent(Intl.DateTimeFormat().resolvedOptions().timeZone)}; path=/; max-age=31536000; samesite=lax`;

syncThemeColor();

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte", {
      eager: true,
    });
    const page = pages[`../pages/${name}.svelte`];
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.svelte'`);
    }
    return page;
  },

  layout: () => AppShell,

  setup({ el, App, props }) {
    if (el) {
      mount(App, { target: el, props });
    } else {
      console.error(
        "Missing root element.\n\n" +
          "If you see this error, it probably means you load Inertia.js on non-Inertia pages.\n" +
          'Consider moving <%= vite_typescript_tag "inertia" %> to the Inertia-specific layout instead.',
      );
    }
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
    },
  },
});
