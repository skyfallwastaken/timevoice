<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import { page } from '@inertiajs/svelte'
  import { Settings, Users, Shield, Trash2, Plus, Crown } from 'lucide-svelte'
  import EmptyState from '../../components/EmptyState.svelte'

  let workspace = $derived($page.props.workspace || {})
  let members = $derived($page.props.members || [])
  let flash = $derived($page.props.flash || {})

  function getRoleIcon(role: string) {
    if (role === 'owner') return Crown
    if (role === 'admin') return Shield
    return Users
  }

  function getRoleColor(role: string) {
    if (role === 'owner') return 'text-bright-yellow'
    if (role === 'admin') return 'text-bright-blue'
    return 'text-fg-muted'
  }
</script>

<AppShell>
  <div class="flex-1 p-6 overflow-auto">
    <div class="max-w-4xl mx-auto space-y-6">
      <!-- Page Header -->
      <div class="flex items-center gap-3">
        <Settings class="w-6 h-6 text-bright-blue" aria-hidden="true" />
        <h2 class="text-2xl font-semibold">Workspace Settings</h2>
      </div>

      <!-- Flash Messages -->
      {#if flash.notice}
        <div class="bg-bright-green/10 border border-bright-green text-bright-green px-4 py-3 rounded-[10px] animate-slide-in">
          {flash.notice}
        </div>
      {/if}
      {#if flash.alert}
        <div class="bg-bright-red/10 border border-bright-red text-bright-red px-4 py-3 rounded-[10px] animate-slide-in">
          {flash.alert}
        </div>
      {/if}

      <!-- Workspace Info -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
        <div class="p-4 border-b border-bg-tertiary">
          <h3 class="font-semibold">General Information</h3>
        </div>
        <div class="p-4 space-y-4">
          <div>
            <label for="workspace-name" class="block text-sm font-medium text-fg-secondary mb-1">
              Workspace Name
            </label>
            <input
              id="workspace-name"
              type="text"
              value={workspace.name}
              readonly
              class="w-full bg-bg-tertiary/50 border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary"
              aria-describedby="workspace-name-help"
            />
            <p id="workspace-name-help" class="text-sm text-fg-muted mt-1">
              Workspace name can only be changed by the owner.
            </p>
          </div>
        </div>
      </div>

      <!-- Members -->
      <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px]">
        <div class="p-4 border-b border-bg-tertiary flex items-center justify-between">
          <div class="flex items-center gap-2">
            <Users class="w-5 h-5 text-fg-muted" aria-hidden="true" />
            <h3 class="font-semibold">Members ({members.length})</h3>
          </div>
          <button 
            class="flex items-center gap-2 px-3 py-1.5 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] text-sm transition-colors duration-150"
            aria-label="Invite new member"
          >
            <Plus class="w-4 h-4" aria-hidden="true" />
            Invite
          </button>
        </div>
        <div class="divide-y divide-bg-tertiary" role="list" aria-label="Workspace members">
          {#each members as membership}
            {@const RoleIcon = getRoleIcon(membership.role)}
            <div 
              class="p-4 flex items-center justify-between hover:bg-bg-tertiary/50 transition-colors duration-150"
              role="listitem"
            >
              <div class="flex items-center gap-3">
                {#if membership.user.avatar_url}
                  <img 
                    src={membership.user.avatar_url} 
                    alt="" 
                    class="w-10 h-10 rounded-full" 
                  />
                {:else}
                  <div 
                    class="w-10 h-10 rounded-full bg-bg-tertiary flex items-center justify-center text-lg font-semibold"
                    aria-hidden="true"
                  >
                    {membership.user.name?.[0]?.toUpperCase() || '?'}
                  </div>
                {/if}
                <div>
                  <p class="font-medium">{membership.user.name}</p>
                  <p class="text-sm text-fg-muted">{membership.user.email}</p>
                </div>
              </div>
              <div class="flex items-center gap-3">
                <span class="flex items-center gap-1 text-sm {getRoleColor(membership.role)}">
                  <RoleIcon class="w-4 h-4" aria-hidden="true" />
                  <span class="capitalize">{membership.role}</span>
                </span>
                {#if membership.role !== 'owner'}
                  <button 
                    class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                    aria-label="Remove {membership.user.name} from workspace"
                  >
                    <Trash2 class="w-4 h-4" aria-hidden="true" />
                  </button>
                {/if}
              </div>
            </div>
          {:else}
            <EmptyState 
              icon={Users}
              title="No members yet"
              description="Invite team members to collaborate on time tracking."
              actionLabel="Invite Member"
              actionHref="/settings/workspace"
            />
          {/each}
        </div>
      </div>

      <!-- Danger Zone -->
      <div class="bg-bg-tertiary/50 border border-bright-red/30 rounded-[10px] p-4">
        <h3 class="font-semibold text-bright-red mb-2">Danger Zone</h3>
        <p class="text-sm text-fg-muted mb-4">
          These actions are irreversible. Please be certain before proceeding.
        </p>
        <button 
          class="px-4 py-2 border border-bright-red text-bright-red hover:bg-bright-red hover:text-bg-primary rounded-[10px] transition-colors duration-150 text-sm"
          aria-label="Delete workspace"
        >
          Delete Workspace
        </button>
      </div>
    </div>
  </div>
</AppShell>
