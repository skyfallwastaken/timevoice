<script module>
  export const layout = false;
</script>

<script lang="ts">
  import { page } from "@inertiajs/svelte";
  import { Link } from "@inertiajs/svelte";
  import { AlertTriangle } from "@lucide/svelte";

  let error = $derived(page.props.error as string);
  let message = $derived(page.props.message as string);
</script>

<div class="min-h-screen bg-bg-primary flex items-center justify-center p-4">
  <div class="w-full max-w-md">
    <div
      class="bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
    >
      <div class="p-8 text-center">
        <div
          class="w-16 h-16 mx-auto mb-4 rounded-full bg-bright-red/20 flex items-center justify-center"
        >
          <AlertTriangle class="w-8 h-8 text-bright-red" />
        </div>
        <h1 class="text-xl font-semibold text-fg-primary mb-2 break-words">
          {error}
        </h1>
        <p class="text-fg-muted">
          {message}
        </p>
      </div>

      <div class="p-6 border-t border-bg-tertiary">
        <Link
          href="/"
          class="flex items-center justify-center w-full h-9 px-4 rounded-[10px] bg-bright-purple hover:bg-accent-purple text-bg-primary text-sm font-medium transition-colors duration-150"
        >
          Return to Timevoice
        </Link>
      </div>
    </div>
  </div>
</div>
