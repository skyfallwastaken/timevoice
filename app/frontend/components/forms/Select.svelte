<script lang="ts" generics="T extends Record<string, any>">
  import type { InertiaForm } from '@inertiajs/svelte'

  interface Option {
    value: string
    label: string
  }

  interface Props {
    form: InertiaForm<T>
    field: keyof T
    label: string
    options: Option[]
    emptyOption?: string
    required?: boolean
    disabled?: boolean
    class?: string
  }

  let {
    form,
    field,
    label,
    options,
    emptyOption = '',
    required = false,
    disabled = false,
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
  <select
    {id}
    bind:value={$form[field]}
    {required}
    {disabled}
    class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-blue transition-colors duration-150"
    class:border-bright-red={error}
    class:focus:border-bright-red={error}
  >
    {#if emptyOption}
      <option value="">{emptyOption}</option>
    {/if}
    {#each options as option}
      <option value={option.value}>{option.label}</option>
    {/each}
  </select>
  {#if error}
    <p class="text-bright-red text-sm mt-1">{error}</p>
  {/if}
</div>
