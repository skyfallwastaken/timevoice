<script lang="ts" module>
  export const layout = false;
</script>

<script lang="ts">
  import { inertia } from "@inertiajs/svelte";
</script>

<svelte:head>
  <title>Timevoice - Time Tracking for Teams</title>
  <meta
    name="description"
    content="Simple, powerful time tracking for freelancers and teams. Track time, manage projects, and create invoices."
  />
</svelte:head>

<a href="#main-content" class="skip-link">Skip to main content</a>

<header
  class="fixed top-0 left-0 right-0 z-50 bg-bg-primary/80 backdrop-blur-md border-b border-bg-tertiary"
>
  <div class="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
    <a href="/" class="flex items-center gap-3" use:inertia>
      <div
        class="w-8 h-8 rounded-lg border border-bg-tertiary bg-bg-secondary flex items-center justify-center text-sm font-semibold"
      >
        T
      </div>
      <span class="font-semibold text-lg">Timevoice</span>
    </a>

    <nav class="flex items-center gap-4">
      <a
        href="/signin"
        class="text-fg-muted hover:text-fg-primary transition-colors px-4 py-2"
        >Sign in</a
      >
      <a
        href="/signin"
        class="bg-bright-blue hover:bg-bright-blue/90 text-bg-primary font-medium px-4 py-2 rounded-lg transition-colors"
        >Get Started</a
      >
    </nav>
  </div>
</header>

<main id="main-content" tabindex="-1" class="min-h-screen">
  <!-- Hero Section -->
  <section class="pt-32 pb-20 px-6">
    <div class="max-w-4xl mx-auto text-center">
      <h1
        class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight mb-6"
      >
        Track time.<br class="hidden sm:block" />
        <span class="text-bright-blue">Invoice clients.</span>
      </h1>
      <p class="text-lg sm:text-xl text-fg-muted max-w-2xl mx-auto mb-10">
        Simple time tracking for freelancers and teams. Start the timer, tag
        your work, and generate invoices in seconds.
      </p>
      <div class="flex flex-col sm:flex-row gap-4 justify-center">
        <a
          href="/signin"
          class="inline-flex items-center justify-center gap-3 bg-bright-blue hover:bg-bright-blue/90 text-bg-primary font-medium px-6 py-3 rounded-lg transition-colors text-lg"
        >
          Get started free
          <svg
            class="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13 7l5 5m0 0l-5 5m5-5H6"
            />
          </svg>
        </a>
      </div>
    </div>
  </section>

  <!-- Features Section -->
  <section class="py-20 px-6 border-t border-bg-tertiary">
    <div class="max-w-6xl mx-auto">
      <h2 class="text-2xl sm:text-3xl font-bold text-center mb-4">
        Everything you need to bill your time
      </h2>
      <p class="text-fg-muted text-center max-w-2xl mx-auto mb-16">
        From quick timers to detailed reports, Timevoice has the tools to track
        every billable minute.
      </p>

      <div class="grid md:grid-cols-3 gap-8">
        <!-- Feature 1 -->
        <div class="bg-bg-secondary border border-bg-tertiary rounded-xl p-6">
          <div
            class="w-12 h-12 rounded-lg bg-accent-blue/20 flex items-center justify-center mb-4"
          >
            <svg
              class="w-6 h-6 text-bright-blue"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>
          <h3 class="text-lg font-semibold mb-2">One-click timer</h3>
          <p class="text-fg-muted">
            Start tracking instantly. Add descriptions, projects, and tags as
            you go or after.
          </p>
        </div>

        <!-- Feature 2 -->
        <div class="bg-bg-secondary border border-bg-tertiary rounded-xl p-6">
          <div
            class="w-12 h-12 rounded-lg bg-accent-green/20 flex items-center justify-center mb-4"
          >
            <svg
              class="w-6 h-6 text-bright-green"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
          </div>
          <h3 class="text-lg font-semibold mb-2">Detailed reports</h3>
          <p class="text-fg-muted">
            Filter by date, project, or client. See exactly where your time
            goes.
          </p>
        </div>

        <!-- Feature 3 -->
        <div class="bg-bg-secondary border border-bg-tertiary rounded-xl p-6">
          <div
            class="w-12 h-12 rounded-lg bg-accent-yellow/20 flex items-center justify-center mb-4"
          >
            <svg
              class="w-6 h-6 text-bright-yellow"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
          </div>
          <h3 class="text-lg font-semibold mb-2">Professional invoices</h3>
          <p class="text-fg-muted">
            Generate PDF invoices from your tracked time. Send to clients
            directly.
          </p>
        </div>

        <!-- Feature 4 -->
        <div class="bg-bg-secondary border border-bg-tertiary rounded-xl p-6">
          <div
            class="w-12 h-12 rounded-lg bg-accent-purple/20 flex items-center justify-center mb-4"
          >
            <svg
              class="w-6 h-6 text-bright-purple"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
              />
            </svg>
          </div>
          <h3 class="text-lg font-semibold mb-2">Team workspaces</h3>
          <p class="text-fg-muted">
            Invite team members to your workspace. Everyone tracks, you invoice.
          </p>
        </div>

        <!-- Feature 5 -->
        <div class="bg-bg-secondary border border-bg-tertiary rounded-xl p-6">
          <div
            class="w-12 h-12 rounded-lg bg-accent-aqua/20 flex items-center justify-center mb-4"
          >
            <svg
              class="w-6 h-6 text-bright-aqua"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
              />
            </svg>
          </div>
          <h3 class="text-lg font-semibold mb-2">Projects & tags</h3>
          <p class="text-fg-muted">
            Organize time entries with projects, clients, and custom tags.
          </p>
        </div>

        <!-- Feature 6 -->
        <div class="bg-bg-secondary border border-bg-tertiary rounded-xl p-6">
          <div
            class="w-12 h-12 rounded-lg bg-accent-orange/20 flex items-center justify-center mb-4"
          >
            <svg
              class="w-6 h-6 text-bright-orange"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
          <h3 class="text-lg font-semibold mb-2">Calendar view</h3>
          <p class="text-fg-muted">
            See your week at a glance. Edit entries inline with drag and drop.
          </p>
        </div>
      </div>
    </div>
  </section>

  <!-- CTA Section -->
  <section class="py-20 px-6 border-t border-bg-tertiary">
    <div class="max-w-3xl mx-auto text-center">
      <h2 class="text-2xl sm:text-3xl font-bold mb-4">
        Start tracking your time today
      </h2>
      <p class="text-fg-muted mb-8">
        Free to get started. No credit card required.
      </p>
      <a
        href="/signin"
        class="inline-flex items-center justify-center gap-3 bg-bright-blue hover:bg-bright-blue/90 text-bg-primary font-medium px-6 py-3 rounded-lg transition-colors text-lg"
      >
        Get started free
        <svg
          class="w-5 h-5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 7l5 5m0 0l-5 5m5-5H6"
          />
        </svg>
      </a>
    </div>
  </section>
</main>

<footer class="border-t border-bg-tertiary py-8 px-6">
  <div
    class="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4"
  >
    <div class="flex items-center gap-3">
      <div
        class="w-6 h-6 rounded border border-bg-tertiary bg-bg-secondary flex items-center justify-center text-xs font-semibold"
      >
        T
      </div>
      <span class="text-fg-muted text-sm"
        >&copy; {new Date().getFullYear()} Timevoice</span
      >
    </div>
  </div>
</footer>
