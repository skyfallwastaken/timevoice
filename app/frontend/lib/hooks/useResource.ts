import { useForm, type InertiaForm } from '@inertiajs/svelte'
import { routes } from '../routes'

// Types for resources that support full CRUD
interface CrudResourceRoutes {
  create: (workspaceId: string) => string
  update: (workspaceId: string, id: number) => string
  delete: (workspaceId: string, id: number) => string
}

// Supported resource types with full CRUD
 type CrudResource = 'clients' | 'projects' | 'tags' | 'timeEntries' | 'invoices'

interface UseResourceOptions<T extends Record<string, any>> {
  workspaceId: () => string
  resource: CrudResource
  initialData: T
}

interface UseResourceReturn<T extends Record<string, any>> {
  form: InertiaForm<T>
  create: (options?: { onSuccess?: () => void }) => void
  update: (id: number, options?: { onSuccess?: () => void }) => void
  destroy: (id: number, options?: { onSuccess?: () => void }) => void
  processing: boolean
  reset: () => void
  clearErrors: () => void
}

export function useResource<T extends Record<string, any>>(
  options: UseResourceOptions<T>
): UseResourceReturn<T> {
  const form = useForm<T>(options.initialData)

  function getRoute(action: 'create' | 'update' | 'delete', id?: number): string {
    const routeGroup = routes[options.resource] as CrudResourceRoutes
    const wsId = options.workspaceId()
    
    switch (action) {
      case 'create':
        return routeGroup.create(wsId)
      case 'update':
        if (id === undefined) throw new Error('ID required for update')
        return routeGroup.update(wsId, id)
      case 'delete':
        if (id === undefined) throw new Error('ID required for delete')
        return routeGroup.delete(wsId, id)
    }
  }

  function create(opts?: { onSuccess?: () => void }) {
    form.post(getRoute('create'), {
      preserveScroll: true,
      onSuccess: () => {
        form.reset()
        opts?.onSuccess?.()
      }
    })
  }

  function update(id: number, opts?: { onSuccess?: () => void }) {
    form.patch(getRoute('update', id), {
      preserveScroll: true,
      onSuccess: () => {
        opts?.onSuccess?.()
      }
    })
  }

  function destroy(id: number, opts?: { onSuccess?: () => void }) {
    form.delete(getRoute('delete', id), {
      preserveScroll: true,
      onSuccess: () => {
        opts?.onSuccess?.()
      }
    })
  }

  return {
    form,
    create,
    update,
    destroy,
    get processing() {
      return form.processing
    },
    reset: () => form.reset(),
    clearErrors: () => form.clearErrors()
  }
}
