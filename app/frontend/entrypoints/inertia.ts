import "../assets/tailwind.css";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import { mount } from "svelte";
import AppShell from "../components/AppShell.svelte";
import * as DashboardIndex from "../pages/Dashboard/Index.svelte";
import { syncThemeColor } from "../lib/theme";

// The timer is the page most visits land on, so it ships in the main bundle;
// every other page is a separate chunk loaded on first use.
const pages: Record<string, () => Promise<ResolvedComponent>> = {
  ...import.meta.glob<ResolvedComponent>([
    "../pages/**/*.svelte",
    "!../pages/Dashboard/Index.svelte",
  ]),
  "../pages/Dashboard/Index.svelte": async () => DashboardIndex,
};

// A deploy removes the chunks an open tab was built against; reload to pick
// up the new ones instead of leaving a visit stuck on a failed import.
window.addEventListener("vite:preloadError", () => window.location.reload());

// The server reads this to bucket entries into days in the browser's timezone.
document.cookie = `tz=${encodeURIComponent(Intl.DateTimeFormat().resolvedOptions().timeZone)}; path=/; max-age=31536000; samesite=lax`;

syncThemeColor();

createInertiaApp({
  resolve: (name) => {
    const page = pages[`../pages/${name}.svelte`];
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.svelte'`);
    }
    return page();
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
