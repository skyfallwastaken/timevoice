<script lang="ts" module>
  export const layout = false;
</script>

<script lang="ts">
  import { page, router } from "@inertiajs/svelte";
  import { Shield, Users, Clock } from "lucide-svelte";
  import Button from "../../components/Button.svelte";

  type Invite = {
    token: string;
    workspace_name: string;
    inviter_name: string;
    inviter_avatar: string | null;
    role: string;
    expires_at: string;
  };

  let invite = $derived($page.props.invite as Invite);
  let flash = $derived($page.props.flash as { notice?: string; alert?: string } | undefined);
  let processing = $state(false);

  function acceptInvite() {
    processing = true;
    router.post(`/invite/${invite.token}/accept`, {}, {
      onFinish: () => {
        processing = false;
      },
    });
  }

  function declineInvite() {
    processing = true;
    router.post(`/invite/${invite.token}/decline`, {}, {
      onFinish: () => {
        processing = false;
      },
    });
  }

  function formatExpiresAt(dateStr: string) {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = date.getTime() - now.getTime();
    const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
    if (diffDays <= 0) return "Expires soon";
    if (diffDays === 1) return "Expires in 1 day";
    return `Expires in ${diffDays} days`;
  }
</script>

<a href="#main-content" class="skip-link">Skip to main content</a>

<div
  class="min-h-screen w-full p-6 flex items-center justify-center overflow-x-hidden"
  role="main"
  id="main-content"
  tabindex="-1"
>
  <div class="max-w-md w-full flex flex-col items-center" style="gap: 2.5rem">
    <div class="flex flex-col items-center gap-4">
      <div
        class="p-24 w-12 h-12 rounded-[10px] border border-bg-tertiary bg-bg-secondary flex items-center justify-center text-xl font-semibold"
      >
        T
      </div>
      <h1 class="text-2xl font-semibold text-center text-fg-primary">
        Workspace Invitation
      </h1>
    </div>

    <div
      class="w-full bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
    >
      {#if flash?.notice}
        <div
          class="bg-bright-green/10 border-b border-bright-green text-bright-green px-4 py-3 text-sm"
          role="status"
          aria-live="polite"
        >
          {flash.notice}
        </div>
      {/if}

      {#if flash?.alert}
        <div
          class="bg-bright-red/10 border-b border-bright-red text-bright-red px-4 py-3 text-sm"
          role="alert"
          aria-live="polite"
        >
          {flash.alert}
        </div>
      {/if}

      <div class="p-6 space-y-6">
        <div class="flex items-center gap-4">
          {#if invite.inviter_avatar}
            <img
              src={invite.inviter_avatar}
              alt=""
              class="w-12 h-12 rounded-full"
            />
          {:else}
            <div
              class="w-12 h-12 rounded-full bg-bg-tertiary flex items-center justify-center text-lg font-semibold"
            >
              {invite.inviter_name?.[0]?.toUpperCase() || "?"}
            </div>
          {/if}
          <div>
            <p class="font-medium text-fg-primary">{invite.inviter_name}</p>
            <p class="text-sm text-fg-muted">invited you to join</p>
          </div>
        </div>

        <div class="bg-bg-tertiary/50 rounded-[10px] p-4 space-y-3">
          <h2 class="text-lg font-semibold text-fg-primary">
            {invite.workspace_name}
          </h2>
          <div class="flex items-center gap-4 text-sm text-fg-muted">
            <span class="flex items-center gap-1.5">
              {#if invite.role === "admin"}
                <Shield class="w-4 h-4" aria-hidden="true" />
              {:else}
                <Users class="w-4 h-4" aria-hidden="true" />
              {/if}
              <span class="capitalize">{invite.role}</span>
            </span>
            <span class="flex items-center gap-1.5">
              <Clock class="w-4 h-4" aria-hidden="true" />
              {formatExpiresAt(invite.expires_at)}
            </span>
          </div>
        </div>

        <div class="flex gap-3">
          <Button
            variant="primary"
            tone="purple"
            size="lg"
            class="flex-1"
            onclick={acceptInvite}
            disabled={processing}
          >
            {processing ? "Processing..." : "Accept Invitation"}
          </Button>
          <Button
            variant="ghost"
            size="lg"
            onclick={declineInvite}
            disabled={processing}
          >
            Decline
          </Button>
        </div>
      </div>
    </div>

    <p class="text-sm text-fg-dim text-center">
      By accepting, you'll join this workspace and can start collaborating with the team.
    </p>
  </div>
</div>
