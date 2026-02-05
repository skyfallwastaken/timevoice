<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { Link, page, router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import { Settings, Users, Shield, Trash2, Plus, Crown } from "lucide-svelte";
  import Turnstile from "../../components/Turnstile.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import Modal from "../../components/Modal.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import ListRow from "../../components/ListRow.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import SelectInput from "../../components/SelectInput.svelte";

  type Membership = {
    id: number;
    role: "owner" | "admin" | "member";
    user: {
      id: number;
      name: string;
      email: string;
      avatar_url: string | null;
    };
  };

  type PendingInvite = {
    id: number;
    email: string;
    role: string;
    inviter_name: string;
    expires_at: string;
    created_at: string;
  };

  let workspace = $derived($page.props.workspace || {});
  let members = $derived(($page.props.members as Membership[]) || []);
  let pendingInvites = $derived(
    ($page.props.pendingInvites as PendingInvite[]) || [],
  );
  let flash = $derived($page.props.flash || {});
  let canInvite = $derived(!!$page.props.canInvite);

  const currentUserId = $derived($page.props.auth?.user?.id);
  const myRole = $derived(
    members.find((m) => m.user?.id === currentUserId)?.role,
  );
  const canManageMembers = $derived(myRole === "owner" || myRole === "admin");
  const canDeleteWorkspace = $derived(myRole === "owner");
  const canEditWorkspace = $derived(myRole === "owner");

  let workspaceName = $state("");
  $effect(() => {
    workspaceName = workspace.name || "";
  });

  let showInviteModal = $state(false);
  let showDeleteModal = $state(false);
  let showRemoveMemberModal = $state(false);
  let showCancelInviteModal = $state(false);
  let memberToRemove = $state<{ id: number; name: string; isSelf: boolean } | null>(null);
  let inviteToCancel = $state<{ id: number; email: string } | null>(null);
  let inviteForm = useForm({
    email: "",
    role: "member",
    "cf-turnstile-response": "",
  });
  let turnstileToken = $state("");

  const workspaceId = $derived($page.props.auth?.workspace?.hashid);

  function submitInvite() {
    $inviteForm.transform((data) => ({
      membership: { email: data.email },
      role: data.role,
      "cf-turnstile-response": turnstileToken,
    })).post(`/${workspaceId}/memberships`, {
      preserveScroll: true,
      onSuccess: () => {
        showInviteModal = false;
        $inviteForm.reset();
        turnstileToken = "";
      },
    });
  }

  function confirmDeleteWorkspace() {
    router.delete(`/${workspaceId}/settings/workspace`);
    showDeleteModal = false;
  }

  function saveWorkspaceName() {
    if (workspaceName.trim() && workspaceName !== workspace.name) {
      router.patch(
        `/${workspaceId}/settings/workspace`,
        {
          workspace: { name: workspaceName.trim() },
        },
        { preserveScroll: true },
      );
    }
  }

  function openRemoveMemberModal(membershipId: number, memberName: string, isSelf: boolean) {
    memberToRemove = { id: membershipId, name: memberName, isSelf };
    showRemoveMemberModal = true;
  }

  function confirmRemoveMember() {
    if (!memberToRemove) return;
    router.delete(`/${workspaceId}/memberships/${memberToRemove.id}`, {
      preserveScroll: !memberToRemove.isSelf,
    });
    showRemoveMemberModal = false;
    memberToRemove = null;
  }

  function getRoleIcon(role: string) {
    if (role === "owner") return Crown;
    if (role === "admin") return Shield;
    return Users;
  }

  function getRoleColor(role: string) {
    if (role === "owner") return "text-bright-yellow";
    if (role === "admin") return "text-bright-blue";
    return "text-fg-muted";
  }

  function openCancelInviteModal(inviteId: number, email: string) {
    inviteToCancel = { id: inviteId, email };
    showCancelInviteModal = true;
  }

  function confirmCancelInvite() {
    if (!inviteToCancel) return;
    router.delete(`/${workspaceId}/invites/${inviteToCancel.id}`, {
      preserveScroll: true,
    });
    showCancelInviteModal = false;
    inviteToCancel = null;
  }

  function formatTimeAgo(dateStr: string) {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / (1000 * 60));
    if (diffMins < 1) return "just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.floor(diffHours / 24);
    return `${diffDays}d ago`;
  }
</script>

<PageLayout
  title="Workspace Settings"
  icon={Settings}
  iconColor="text-bright-blue"
  variant="narrow"
  {flash}
>
  <SectionCard class="overflow-hidden" bodyClass="p-0">
    <div class="grid grid-cols-3">
      <Link
        href="/{workspaceId}/settings/workspace"
        class="px-4 py-2 text-sm font-medium bg-bg-tertiary text-fg-primary border-r border-bg-tertiary"
        aria-current="page"
      >
        Workspace
      </Link>
      <Link
        href="/{workspaceId}/settings/billing"
        class="px-4 py-2 text-sm font-medium text-fg-secondary hover:bg-bg-tertiary transition-colors duration-150 border-r border-bg-tertiary"
      >
        Billing
      </Link>
      <Link
        href="/{workspaceId}/settings/developer"
        class="px-4 py-2 text-sm font-medium text-fg-secondary hover:bg-bg-tertiary transition-colors duration-150"
      >
        Developer
      </Link>
    </div>
  </SectionCard>

  <SectionCard title="General Information" bodyClass="p-4">
    <div class="space-y-4">
      <FormField
        id="workspace-name"
        label="Workspace Name"
        description={!canEditWorkspace
          ? "Workspace name can only be changed by the owner."
          : undefined}
      >
        {#snippet children({ describedBy })}
          <div class="flex gap-2">
            <input
              id="workspace-name"
              type="text"
              bind:value={workspaceName}
              readonly={!canEditWorkspace}
              onkeydown={(e) => e.key === "Enter" && saveWorkspaceName()}
              aria-describedby={describedBy}
              class="flex-1 bg-bg-tertiary/50 border border-bg-tertiary rounded-[10px] px-4 py-2 text-fg-primary {canEditWorkspace
                ? 'focus:outline-none focus:border-bright-purple'
                : ''}"
            />
            {#if canEditWorkspace && workspaceName.trim() && workspaceName !== workspace.name}
              <Button tone="purple" size="sm" type="button" onclick={saveWorkspaceName}>
                Save
              </Button>
            {/if}
          </div>
        {/snippet}
      </FormField>
    </div>
  </SectionCard>

  <SectionCard title={`Members (${members.length})`} icon={Users}>
    {#snippet headerActions()}
      <Button
        tone="purple"
        size="sm"
        aria-label="Invite new member"
        type="button"
        onclick={() => {
          $inviteForm.reset();
          showInviteModal = true;
        }}
        disabled={!canInvite}
        title={canInvite ? "Invite a member" : "Only admins can invite members"}
        class="disabled:hover:bg-bright-purple"
      >
        <Plus class="w-4 h-4" aria-hidden="true" />
        Invite
      </Button>
    {/snippet}
    <div
      class="divide-y divide-bg-tertiary"
      role="list"
      aria-label="Workspace members"
    >
      {#each members as membership, i}
        {@const RoleIcon = getRoleIcon(membership.role)}
        {@const isLast = i === members.length - 1}
        <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
          {#snippet leading()}
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
                {membership.user.name?.[0]?.toUpperCase() || "?"}
              </div>
            {/if}
          {/snippet}
          {#snippet primary()}
            {membership.user.name}
          {/snippet}
          {#snippet secondary()}
            {membership.user.email}
          {/snippet}
          {#snippet meta()}
            <span class="flex items-center gap-1 {getRoleColor(membership.role)}">
              <RoleIcon class="w-4 h-4" aria-hidden="true" />
              <span class="capitalize">{membership.role}</span>
            </span>
          {/snippet}
          {#snippet actions()}
            {#if membership.role !== "owner" && (canManageMembers || membership.user?.id === currentUserId)}
              {@const isSelf = membership.user?.id === currentUserId}
              <IconButton
                tone="danger"
                aria-label={isSelf ? "Leave workspace" : `Remove ${membership.user.name} from workspace`}
                onclick={() =>
                  openRemoveMemberModal(membership.id, membership.user.name, isSelf)}
              >
                <Trash2 class="w-4 h-4" aria-hidden="true" />
              </IconButton>
            {/if}
          {/snippet}
        </ListRow>
      {:else}
        <EmptyState
          icon={Users}
          title="No members yet"
          description="Invite team members to collaborate on time tracking."
          actionLabel="Invite Member"
          actionHref="/{workspaceId}/settings/workspace"
        />
      {/each}
    </div>
  </SectionCard>

  {#if pendingInvites.length > 0 && canManageMembers}
    <SectionCard title={`Pending Invites (${pendingInvites.length})`} icon={Users}>
      <div
        class="divide-y divide-bg-tertiary"
        role="list"
        aria-label="Pending invitations"
      >
        {#each pendingInvites as invite, i}
          {@const isLast = i === pendingInvites.length - 1}
          <ListRow class={isLast ? "rounded-b-[10px]" : ""}>
            {#snippet leading()}
              <div
                class="w-10 h-10 rounded-full bg-bg-tertiary flex items-center justify-center text-lg font-semibold text-fg-muted"
                aria-hidden="true"
              >
                ?
              </div>
            {/snippet}
            {#snippet primary()}
              {invite.email}
            {/snippet}
            {#snippet secondary()}
              Invited by {invite.inviter_name} · {formatTimeAgo(invite.created_at)}
            {/snippet}
            {#snippet meta()}
              <span class="flex items-center gap-1 {getRoleColor(invite.role)}">
                {#if invite.role === "admin"}
                  <Shield class="w-4 h-4" aria-hidden="true" />
                {:else}
                  <Users class="w-4 h-4" aria-hidden="true" />
                {/if}
                <span class="capitalize">{invite.role}</span>
              </span>
            {/snippet}
            {#snippet actions()}
              <IconButton
                tone="danger"
                aria-label="Cancel invitation to {invite.email}"
                onclick={() => openCancelInviteModal(invite.id, invite.email)}
              >
                <Trash2 class="w-4 h-4" aria-hidden="true" />
              </IconButton>
            {/snippet}
          </ListRow>
        {/each}
      </div>
    </SectionCard>
  {/if}

  <div class="bg-bg-tertiary/50 border border-bright-red/30 rounded-[10px] p-4">
    <h3 class="font-semibold text-bright-red mb-2">Danger Zone</h3>
    <p class="text-sm text-fg-muted mb-4">
      These actions are irreversible. Please be certain before proceeding.
    </p>
    <Button
      variant="outline"
      tone="red"
      size="sm"
      class="border-bright-red text-bright-red hover:bg-bright-red hover:text-bg-primary"
      aria-label="Delete workspace"
      onclick={() => (showDeleteModal = true)}
      disabled={!canDeleteWorkspace}
      title={canDeleteWorkspace
        ? "Delete workspace"
        : "Only the owner can delete the workspace"}
    >
      Delete Workspace
    </Button>
  </div>

  <Modal
    bind:open={showInviteModal}
    title="Invite Member"
    onclose={() => {
      showInviteModal = false;
      $inviteForm.reset();
    }}
  >
    <FormField id="invite-email" label="Email">
      {#snippet children({ describedBy })}
        <TextInput
          id="invite-email"
          type="email"
          tone="purple"
          bind:value={$inviteForm.email}
          placeholder="name@company.com"
          onkeydown={(e) => e.key === "Enter" && $inviteForm.email && submitInvite()}
          aria-describedby={describedBy}
          autocomplete="email"
        />
      {/snippet}
    </FormField>

    <FormField
      id="invite-role"
      label="Role"
      description="They'll receive an invitation link sent to their email."
    >
      {#snippet children({ describedBy })}
        <SelectInput
          id="invite-role"
          tone="purple"
          bind:value={$inviteForm.role}
          aria-describedby={describedBy}
        >
          <option value="member">Member</option>
          <option value="admin">Admin</option>
        </SelectInput>
      {/snippet}
    </FormField>

    <div class="mt-4">
      <Turnstile onSuccess={(token) => (turnstileToken = token)} />
    </div>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          onclick={() => {
            showInviteModal = false;
            $inviteForm.reset();
          }}
          disabled={$inviteForm.processing}
        >
          Cancel
        </Button>
        <Button
          type="button"
          tone="purple"
          onclick={submitInvite}
          disabled={$inviteForm.processing || !$inviteForm.email}
        >
          {$inviteForm.processing ? "Inviting..." : "Invite"}
        </Button>
      </div>
    {/snippet}
  </Modal>

  <Modal
    bind:open={showDeleteModal}
    title="Delete Workspace"
    onclose={() => (showDeleteModal = false)}
  >
    <div class="space-y-4">
      <p class="text-fg-primary">
        Are you sure you want to delete <span class="font-semibold"
          >{workspace?.name || "this workspace"}</span
        >?
      </p>
      <p class="text-sm text-fg-muted">
        This action cannot be undone. All data including time entries, projects,
        clients, and invoices will be permanently deleted.
      </p>
    </div>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button type="button" variant="ghost" onclick={() => (showDeleteModal = false)}>
          Cancel
        </Button>
        <Button type="button" tone="red" onclick={confirmDeleteWorkspace}>
          Delete Workspace
        </Button>
      </div>
    {/snippet}
  </Modal>

  <Modal
    bind:open={showRemoveMemberModal}
    title={memberToRemove?.isSelf ? "Leave Workspace" : "Remove Member"}
    onclose={() => {
      showRemoveMemberModal = false;
      memberToRemove = null;
    }}
  >
    <div class="space-y-4">
      {#if memberToRemove?.isSelf}
        <p class="text-fg-primary">
          Are you sure you want to leave this workspace?
        </p>
        <p class="text-sm text-fg-muted">
          You will no longer have access to this workspace's time entries, projects, or invoices.
        </p>
      {:else}
        <p class="text-fg-primary">
          Are you sure you want to remove <span class="font-semibold">{memberToRemove?.name}</span> from this workspace?
        </p>
        <p class="text-sm text-fg-muted">
          They will no longer have access to this workspace.
        </p>
      {/if}
    </div>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          onclick={() => {
            showRemoveMemberModal = false;
            memberToRemove = null;
          }}
        >
          Cancel
        </Button>
        <Button type="button" tone="red" onclick={confirmRemoveMember}>
          {memberToRemove?.isSelf ? "Leave Workspace" : "Remove Member"}
        </Button>
      </div>
    {/snippet}
  </Modal>

  <Modal
    bind:open={showCancelInviteModal}
    title="Cancel Invitation"
    onclose={() => {
      showCancelInviteModal = false;
      inviteToCancel = null;
    }}
  >
    <div class="space-y-4">
      <p class="text-fg-primary">
        Are you sure you want to cancel the invitation to <span class="font-semibold">{inviteToCancel?.email}</span>?
      </p>
      <p class="text-sm text-fg-muted">
        They will no longer be able to join this workspace using this invitation.
      </p>
    </div>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          onclick={() => {
            showCancelInviteModal = false;
            inviteToCancel = null;
          }}
        >
          Keep Invitation
        </Button>
        <Button type="button" tone="red" onclick={confirmCancelInvite}>
          Cancel Invitation
        </Button>
      </div>
    {/snippet}
  </Modal>
</PageLayout>
