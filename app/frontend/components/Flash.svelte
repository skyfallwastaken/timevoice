<script lang="ts">
  import { page } from "@inertiajs/svelte";
  import { Check, AlertCircle } from "lucide-svelte";

  let flash = $derived($page.props.flash || {});
</script>

{#if flash.notice}
  <div
    class="bg-bright-green/20 border border-bright-green/50 text-bright-green px-4 py-3 rounded-[10px] mb-4 flex items-center gap-2"
  >
    <Check class="w-5 h-5 flex-shrink-0" />
    <p class="flex-1">{flash.notice}</p>
  </div>
{/if}

{#if flash.alert}
  <div
    class="bg-bright-red/20 border border-bright-red/50 text-bright-red px-4 py-3 rounded-[10px] mb-4 flex items-center gap-2"
  >
    <AlertCircle class="w-5 h-5 flex-shrink-0" />
    <p class="flex-1">{flash.alert}</p>
  </div>
{/if}
