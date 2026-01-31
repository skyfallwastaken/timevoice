<script lang="ts" generics="T extends Record<string, any>">
  import { useForm, type InertiaForm } from '@inertiajs/svelte'
  import type { Snippet } from 'svelte'

  type FormMethod = 'post' | 'patch' | 'put' | 'delete'

  interface Props {
    initialData: T
    action: string
    method?: FormMethod
    onSuccess?: () => void
    onError?: () => void
    preserveScroll?: boolean
    children: Snippet<[{ form: InertiaForm<T>; submit: () => void; processing: boolean }]>
  }

  let {
    initialData,
    action,
    method = 'post',
    onSuccess,
    onError,
    preserveScroll = true,
    children
  }: Props = $props()

  let form = useForm<T>(initialData)

  function submit() {
    const options = {
      preserveScroll,
      onSuccess,
      onError
    }

    switch (method) {
      case 'post':
        $form.post(action, options)
        break
      case 'patch':
        $form.patch(action, options)
        break
      case 'put':
        $form.put(action, options)
        break
      case 'delete':
        $form.delete(action, options)
        break
    }
  }

  function handleSubmit(e: Event) {
    e.preventDefault()
    submit()
  }

  export function reset() {
    $form.reset()
  }

  export function clearErrors() {
    $form.clearErrors()
  }
</script>

<form onsubmit={handleSubmit}>
  {@render children({ form, submit, processing: $form.processing })}
</form>
