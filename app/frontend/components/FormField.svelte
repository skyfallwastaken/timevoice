<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    id: string;
    label: string;
    description?: string;
    error?: string | string[];
    required?: boolean;
    srOnly?: boolean;
    children: Snippet<[{ describedBy: string | undefined }]>;
  }

  let {
    id,
    label,
    description,
    error,
    required = false,
    srOnly = false,
    children,
  }: Props = $props();

  let labelClass = $derived(
    srOnly
      ? "block text-sm font-medium text-fg-secondary mb-1 sr-only"
      : "block text-sm font-medium text-fg-secondary mb-1"
  );

  let errorText = $derived(
    Array.isArray(error) ? error[0] : error
  );

  let helpId = $derived(description ? `${id}-help` : undefined);
  let errorId = $derived(errorText ? `${id}-error` : undefined);
  let describedBy = $derived(
    [helpId, errorId].filter(Boolean).join(" ") || undefined
  );
</script>

<div>
  <label for={id} class={labelClass}>
    {label}
    {#if required}
      <span class="text-bright-red">*</span>
    {/if}
  </label>
  {@render children({ describedBy })}
  {#if description}
    <p id={helpId} class="text-sm text-fg-muted mt-1">
      {description}
    </p>
  {/if}
  {#if errorText}
    <p id={errorId} class="text-sm text-bright-red mt-1">
      {errorText}
    </p>
  {/if}
</div>
