<script lang="ts" generics="T extends Record<string, any>">
  import type { InertiaForm } from '@inertiajs/svelte'

  interface Props {
    form: InertiaForm<T>
    field: keyof T
    label: string
    disabled?: boolean
    class?: string
  }

  let {
    form,
    field,
    label,
    disabled = false,
    class: className = ''
  }: Props = $props()

  let id = `${String(field)}-${Math.random().toString(36).substr(2, 9)}`
</script>

<label class="flex items-center gap-2 cursor-pointer {className}">
  <input
    {id}
    type="checkbox"
    bind:checked={$form[field]}
    {disabled}
    class="w-4 h-4 rounded border-bg-tertiary bg-bg-primary text-bright-blue focus:ring-bright-blue transition-colors duration-150"
  />
  <span class="text-sm text-fg-secondary">{label}</span>
</label>
