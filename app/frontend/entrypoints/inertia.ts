import "../assets/tailwind.css";
import { createInertiaApp, type ResolvedComponent } from "@inertiajs/svelte";
import { mount } from "svelte";
import AppShell from "../components/AppShell.svelte";

const defaultLayout = AppShell as unknown as NonNullable<
  ResolvedComponent["layout"]
>;

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob<ResolvedComponent>("../pages/**/*.svelte", {
      eager: true,
    });
    const page = pages[`../pages/${name}.svelte`] as
      | ResolvedComponent
      | undefined;
    if (!page) {
      console.error(`Missing Inertia page component: '${name}.svelte'`);
    }

    return {
      ...page,
      layout: page?.layout === undefined ? AppShell : page.layout,
    } as ResolvedComponent;
  },

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
    future: {
      useScriptElementForInitialPage: true,
      useDataInertiaHeadAttribute: true,
      useDialogForErrorModal: true,
      preserveEqualProps: true,
    },
  },
});
