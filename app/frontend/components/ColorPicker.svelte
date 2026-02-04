<script lang="ts">
  let {
    colors,
    value = $bindable(),
  }: {
    colors: string[];
    value: string;
  } = $props();
</script>

<div>
  <span class="block text-sm font-medium text-fg-secondary mb-2">Color</span>
  <div class="flex flex-wrap gap-2">
    {#each colors as color}
      <button
        type="button"
        onclick={() => (value = color)}
        class="w-8 h-8 rounded-full border-2 transition-all duration-150 {value ===
        color
          ? 'border-fg-primary scale-110'
          : 'border-transparent hover:scale-105'}"
        style="background-color: {color}"
        aria-label="Select color {color}"
      ></button>
    {/each}
  </div>
</div>
