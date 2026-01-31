<script lang="ts" generics="T extends Record<string, any>">
  import type { InertiaForm } from '@inertiajs/svelte'

  interface Props {
    form: InertiaForm<T>
    field: keyof T
    label: string
    type?: 'text' | 'email' | 'password' | 'number' | 'url' | 'tel'
    placeholder?: string
    required?: boolean
    disabled?: boolean
    autofocus?: boolean
    autocomplete?: string
    class?: string
  }

  let {
    form,
    field,
    label,
    type = 'text',
    placeholder = '',
    required = false,
    disabled = false,
    autofocus = false,
    autocomplete = '',
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
  <input
    {id}
    {type}
    bind:value={$form[field]}
    {placeholder}
    {required}
    {disabled}
    {autofocus}
    {autocomplete}
    class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-blue transition-colors duration-150"
    class:border-bright-red={error}
    class:focus:border-bright-red={error}
  />
  {#if error}
    <p class="text-bright-red text-sm mt-1">{error}</p>
  {/if}
</div>
