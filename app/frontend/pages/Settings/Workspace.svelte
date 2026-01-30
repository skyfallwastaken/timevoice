<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import PageLayout from '../../components/PageLayout.svelte'
  import { page, router } from '@inertiajs/svelte'
  import { useForm } from '@inertiajs/svelte'
  import { Settings, Users, Shield, Trash2, Plus, Crown, X } from 'lucide-svelte'
  import EmptyState from '../../components/EmptyState.svelte'

  type Membership = {
    id: number
    role: 'owner' | 'admin' | 'member'
    user: {
      id: number
      name: string
      email: string
      avatar_url: string | null
    }
  }

  let workspace = $derived($page.props.workspace || {})
  let members = $derived($page.props.members as Membership[] || [])
  let flash = $derived($page.props.flash || {})
  let canInvite = $derived(!!$page.props.canInvite)

  const currentUserId = $derived($page.props.auth?.user?.id)
  const myRole = $derived(members.find((m) => m.user?.id === currentUserId)?.role)
  const canManageMembers = $derived(myRole === 'owner' || myRole === 'admin')
  const canDeleteWorkspace = $derived(myRole === 'owner')

  let showInviteModal = $state(false)
  let inviteForm = useForm({
    email: '',
    role: 'member'
  })

  function openInvite() {
    $inviteForm.reset()
    showInviteModal = true
  }

  function closeInvite() {
    showInviteModal = false
    $inviteForm.reset()
  }

  function submitInvite() {
    $inviteForm.post('/memberships', {
      preserveScroll: true,
      onSuccess: () => {
        closeInvite()
      }
    })
  }

  function deleteWorkspace() {
    if (!canDeleteWorkspace) return

    const name = workspace?.name || 'this workspace'
    const ok = window.confirm(`Delete ${name}? This cannot be undone.`)
    if (!ok) return

    router.delete('/settings/workspace')
  }

  function removeMember(membershipId: number, memberName: string) {
    const ok = window.confirm(`Remove ${memberName} from this workspace?`)
    if (!ok) return

    router.delete(`/memberships/${membershipId}`, { preserveScroll: true })
  }

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
  <PageLayout title="Workspace Settings" icon={Settings} iconColor="text-bright-blue" variant="narrow" flash={flash}>
    <!-- Settings Navigation -->
    <div class="bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden">
      <div class="grid grid-cols-2">
        <a
          href="/settings/workspace"
          class="px-4 py-2 text-sm font-medium bg-bg-tertiary text-fg-primary border-r border-bg-tertiary"
          aria-current="page"
        >
          Workspace
        </a>
        <a
          href="/settings/billing"
          class="px-4 py-2 text-sm font-medium text-fg-secondary hover:bg-bg-tertiary transition-colors duration-150"
        >
          Billing
        </a>
      </div>
    </div>

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
          class="flex items-center gap-2 px-3 py-1.5 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] text-sm transition-colors duration-150 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-bright-purple"
          aria-label="Invite new member"
          type="button"
          onclick={openInvite}
          disabled={!canInvite}
          title={canInvite ? 'Invite a member' : 'Only admins can invite members'}
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
              {#if membership.role !== 'owner' && (canManageMembers || membership.user?.id === currentUserId)}
                <button 
                  class="p-2 text-fg-muted hover:text-bright-red transition-colors duration-150"
                  aria-label="Remove {membership.user.name} from workspace"
                  onclick={() => removeMember(membership.id, membership.user.name)}
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
        onclick={deleteWorkspace}
        disabled={!canDeleteWorkspace}
        title={canDeleteWorkspace ? 'Delete workspace' : 'Only the owner can delete the workspace'}
      >
        Delete Workspace
      </button>
    </div>

    {#if showInviteModal}
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-label="Invite member">
        <div class="absolute inset-0 bg-black/50" onclick={closeInvite} aria-hidden="true"></div>
        <div class="relative w-full max-w-md bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden">
          <div class="p-4 border-b border-bg-tertiary flex items-center justify-between">
            <h3 class="font-semibold">Invite Member</h3>
            <button
              type="button"
              class="p-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
              onclick={closeInvite}
              aria-label="Close"
            >
              <X class="w-4 h-4" aria-hidden="true" />
            </button>
          </div>
          <div class="p-4 space-y-4">
            <div>
              <label for="invite-email" class="block text-sm font-medium text-fg-secondary mb-1">Email</label>
              <input
                id="invite-email"
                type="email"
                bind:value={$inviteForm.email}
                placeholder="name@company.com"
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary placeholder:text-fg-dim focus:outline-none focus:border-bright-purple transition-colors duration-150"
                autocomplete="email"
              />
            </div>

            <div>
              <label for="invite-role" class="block text-sm font-medium text-fg-secondary mb-1">Role</label>
              <select
                id="invite-role"
                bind:value={$inviteForm.role}
                class="w-full bg-bg-primary border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary focus:outline-none focus:border-bright-purple transition-colors duration-150"
              >
                <option value="member">Member</option>
                <option value="admin">Admin</option>
              </select>
              <p class="text-xs text-fg-muted mt-1">They must have signed in before you can add them.</p>
            </div>
          </div>
          <div class="p-4 border-t border-bg-tertiary flex items-center justify-end gap-2">
            <button
              type="button"
              class="px-4 py-2 text-fg-muted hover:text-fg-primary transition-colors duration-150"
              onclick={closeInvite}
              disabled={$inviteForm.processing}
            >
              Cancel
            </button>
            <button
              type="button"
              class="px-4 py-2 bg-bright-purple hover:bg-accent-purple text-bg-primary rounded-[10px] transition-colors duration-150 font-medium disabled:opacity-50"
              onclick={submitInvite}
              disabled={$inviteForm.processing || !$inviteForm.email}
            >
              {$inviteForm.processing ? 'Inviting...' : 'Invite'}
            </button>
          </div>
        </div>
      </div>
    {/if}
  </PageLayout>
</AppShell>
