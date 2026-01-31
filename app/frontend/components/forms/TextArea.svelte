<script lang="ts" generics="T extends Record<string, any>">
  import type { InertiaForm } from '@inertiajs/svelte'

  interface Props {
    form: InertiaForm<T>
    field: keyof T
    label: string
    placeholder?: string
    required?: boolean
    disabled?: boolean
    rows?: number
    class?: string
  }

  let {
    form,
    field,
    label,
    placeholder = '',
    required = false,
    disabled = false,
    rows = 3,
    class: className = ''
  }: Props = $props()

  let id = `${String(field)}-${Math.random().toString(36).substr(2, 9)}`
  let error = $derived($form.errors[String(field)])
</script>

<div class={className}>
  <label for={id} class="block text-sm font-medium text-fg-secondary mb-1">
    {label}
    {#if required}
      <span class="text-bright-red">*</span>
    {/if}
  </label>
  <textarea
    {id}
    bind:value={$form[field]}
    {placeholder}
    {required}
    {disabled}
    {rows}
    class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue transition-colors duration-150 resize-none"
    class:border-bright-red={error}
    class:focus:border-bright-red={error}
  ></textarea>
  {#if error}
    <p class="text-bright-red text-sm mt-1">{error}</p>
  {/if}
</div>
