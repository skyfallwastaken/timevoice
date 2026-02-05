<script module>
  export const layout = false;
</script>

<script lang="ts">
  import { page } from "@inertiajs/svelte";
  import { Check, AlertTriangle, X } from "lucide-svelte";
  import Button from "../../components/Button.svelte";

  type Scope = {
    name: string;
    title: string;
    description: string;
  };

  type Application = {
    name: string;
    trust_level: string;
    owner_name: string;
  };

  let application = $derived($page.props.application as Application);
  let clientId = $derived($page.props.client_id as string);
  let scopes = $derived(($page.props.scopes as Scope[]) || []);
  let responseType = $derived($page.props.response_type as string);
  let redirectUri = $derived($page.props.redirect_uri as string);
  let oauthState = $derived($page.props.state as string | undefined);
  let codeChallenge = $derived(
    $page.props.code_challenge as string | undefined,
  );
  let codeChallengeMethod = $derived(
    $page.props.code_challenge_method as string | undefined,
  );
  let csrfToken = $derived($page.props.csrf_token as string);
  let user = $derived($page.props.auth?.user);

  let isSubmitting = $state(false);
  let authorizeForm = $state<HTMLFormElement | null>(null);
  let denyForm = $state<HTMLFormElement | null>(null);

  function handleAuthorize() {
    isSubmitting = true;
    authorizeForm?.submit();
  }

  function handleDeny() {
    isSubmitting = true;
    denyForm?.submit();
  }
</script>

<div class="min-h-screen bg-bg-primary flex items-center justify-center p-8">
  <div class="w-full max-w-md">
    <div
      class="bg-bg-secondary border border-bg-tertiary rounded-[10px] overflow-hidden"
    >
      <!-- Header -->
      <div class="p-6 border-b border-bg-tertiary text-center">
        <h1 class="text-lg font-semibold text-fg-primary">
          Authorize {application.name}
        </h1>
        <p class="text-sm text-fg-muted mt-1">
          by {application.owner_name}
          {#if application.trust_level === "community"}
            <span
              class="ml-2 inline-flex items-center gap-1 px-2 py-0.5 bg-bright-yellow/20 text-bright-yellow text-xs rounded-full"
            >
              <AlertTriangle class="w-3 h-3" />
              Community
            </span>
          {:else}
            <span
              class="ml-2 inline-flex items-center gap-1 px-2 py-0.5 bg-bright-green/20 text-bright-green text-xs rounded-full"
            >
              <Check class="w-3 h-3" />
              Official
            </span>
          {/if}
        </p>
      </div>

      <!-- Permissions -->
      <div class="p-6 space-y-3">
        {#if scopes.length > 0}
          <div class="space-y-3">
            <h3
              class="text-xs font-medium text-fg-muted uppercase tracking-wide"
            >
              This will allow the app to:
            </h3>
            <ul class="space-y-1.5">
              {#each scopes as scope}
                <li class="flex items-start gap-2 p-2 bg-bg-primary rounded-lg">
                  <Check
                    class="w-4 h-4 text-bright-green shrink-0 mt-1.25 ml-1"
                  />
                  <div>
                    <span class="text-sm font-medium text-fg-primary"
                      >{scope.title}</span
                    >
                    <p class="text-xs text-fg-muted mb-1">
                      {scope.description}
                    </p>
                  </div>
                </li>
              {/each}
            </ul>
          </div>
        {/if}

        {#if application.trust_level === "community"}
          <div
            class="mt-2 p-2 bg-bright-yellow/10 border border-bright-yellow/30 rounded-lg"
          >
            <p class="text-xs text-fg-secondary">
              <strong class="text-bright-yellow">Note:</strong> Community app — only
              authorize if you trust the developer.
            </p>
          </div>
        {/if}
      </div>

      <!-- Actions -->
      <div class="p-4 border-t border-bg-tertiary space-y-2">
        <form bind:this={authorizeForm} action="/oauth/authorize" method="post">
          <input type="hidden" name="authenticity_token" value={csrfToken} />
          <input type="hidden" name="client_id" value={clientId} />
          <input type="hidden" name="redirect_uri" value={redirectUri} />
          <input type="hidden" name="response_type" value={responseType} />
          {#if oauthState}
            <input type="hidden" name="state" value={oauthState} />
          {/if}
          {#if codeChallenge}
            <input type="hidden" name="code_challenge" value={codeChallenge} />
          {/if}
          {#if codeChallengeMethod}
            <input
              type="hidden"
              name="code_challenge_method"
              value={codeChallengeMethod}
            />
          {/if}
          <input
            type="hidden"
            name="scope"
            value={scopes.map((s) => s.name).join(" ")}
          />
          <Button
            type="button"
            tone="green"
            class="w-full"
            disabled={isSubmitting}
            onclick={handleAuthorize}
          >
            <Check class="w-4 h-4" />
            Authorize {application.name}
          </Button>
        </form>

        <form bind:this={denyForm} action="/oauth/authorize" method="post">
          <input type="hidden" name="authenticity_token" value={csrfToken} />
          <input type="hidden" name="client_id" value={clientId} />
          <input type="hidden" name="redirect_uri" value={redirectUri} />
          <input type="hidden" name="response_type" value={responseType} />
          {#if oauthState}
            <input type="hidden" name="state" value={oauthState} />
          {/if}
          {#if codeChallenge}
            <input type="hidden" name="code_challenge" value={codeChallenge} />
          {/if}
          {#if codeChallengeMethod}
            <input
              type="hidden"
              name="code_challenge_method"
              value={codeChallengeMethod}
            />
          {/if}
          <input
            type="hidden"
            name="scope"
            value={scopes.map((s) => s.name).join(" ")}
          />
          <input type="hidden" name="deny" value="true" />
          <Button
            type="button"
            variant="outline"
            tone="red"
            disabled={isSubmitting}
            class="w-full border-bright-red text-bright-red hover:bg-bright-red hover:text-bg-primary"
            onclick={handleDeny}
          >
            <X class="w-4 h-4" />
            Deny
          </Button>
        </form>
      </div>

      <!-- Footer -->
      <div class="px-4 py-3 bg-bg-primary border-t border-bg-tertiary">
        <p class="text-xs text-fg-dim text-center truncate">
          Redirects to <span class="font-mono">{redirectUri}</span>
        </p>
      </div>
    </div>
  </div>
</div>
