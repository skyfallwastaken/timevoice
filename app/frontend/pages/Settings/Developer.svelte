<script lang="ts">
  import PageLayout from "../../components/PageLayout.svelte";
  import { Link, page, router } from "@inertiajs/svelte";
  import { useForm } from "@inertiajs/svelte";
  import {
    Code,
    Plus,
    Trash2,
    RefreshCw,
    Copy,
    Check,
    Key,
    ExternalLink,
    Play,
  } from "lucide-svelte";
  import ChipButton from "../../components/ChipButton.svelte";
  import EmptyState from "../../components/EmptyState.svelte";
  import Modal from "../../components/Modal.svelte";
  import ConfirmDeleteModal from "../../components/ConfirmDeleteModal.svelte";
  import SectionCard from "../../components/SectionCard.svelte";
  import Button from "../../components/Button.svelte";
  import FormField from "../../components/FormField.svelte";
  import IconButton from "../../components/IconButton.svelte";
  import TextInput from "../../components/TextInput.svelte";
  import { routes } from "../../lib/routes";

  type OAuthApp = {
    id: number;
    name: string;
    uid: string;
    secret: string;
    redirect_uri: string;
    scopes: string[];
    trust_level: string;
    confidential: boolean;
    created_at: string;
  };

  type ScopeDescription = {
    [key: string]: string;
  };

  let applications = $derived(($page.props.applications as OAuthApp[]) || []);
  let scopes = $derived(($page.props.scopes as ScopeDescription) || {});
  let flash = $derived(
    ($page.props.flash || {}) as {
      notice?: string;
      alert?: string;
      new_secret?: string;
      secret_app_id?: number;
    },
  );
  let workspaceId = $derived($page.props.auth?.workspace?.hashid as string);

  let showCreateModal = $state(false);
  let showEditModal = $state(false);
  let showDeleteModal = $state(false);
  let showSecretModal = $state(false);
  let selectedApp = $state<OAuthApp | null>(null);
  let copiedField = $state<string | null>(null);

  let createForm = useForm({
    name: "",
    redirect_uri: "",
    scopes: [] as string[],
    confidential: false,
  });

  let editForm = useForm({
    name: "",
    redirect_uri: "",
    scopes: [] as string[],
    confidential: false,
  });

  function submitCreate() {
    $createForm.post(routes.oauthApplications.create(workspaceId), {
      preserveScroll: true,
      onSuccess: () => {
        showCreateModal = false;
        $createForm.reset();
      },
    });
  }

  function openEditModal(app: OAuthApp) {
    selectedApp = app;
    $editForm.name = app.name;
    $editForm.redirect_uri = app.redirect_uri;
    $editForm.scopes = [...app.scopes];
    $editForm.confidential = app.confidential;
    showEditModal = true;
  }

  function submitEdit() {
    if (!selectedApp) return;
    $editForm.patch(
      routes.oauthApplications.update(workspaceId, selectedApp.id),
      {
        preserveScroll: true,
        onSuccess: () => {
          showEditModal = false;
          selectedApp = null;
        },
      },
    );
  }

  function openDeleteModal(app: OAuthApp) {
    selectedApp = app;
    showDeleteModal = true;
  }

  function confirmDelete() {
    if (!selectedApp) return;
    router.delete(
      routes.oauthApplications.delete(workspaceId, selectedApp.id),
      {
        preserveScroll: true,
      },
    );
    showDeleteModal = false;
    selectedApp = null;
  }

  function openSecretModal(app: OAuthApp) {
    selectedApp = app;
    showSecretModal = true;
  }

  function confirmRegenerateSecret() {
    if (!selectedApp) return;
    router.post(
      routes.oauthApplications.regenerateSecret(workspaceId, selectedApp.id),
      {},
      {
        preserveScroll: true,
      },
    );
    showSecretModal = false;
    selectedApp = null;
  }

  async function copyToClipboard(text: string, field: string) {
    await navigator.clipboard.writeText(text);
    copiedField = field;
    setTimeout(() => {
      copiedField = null;
    }, 2000);
  }

  function toggleScope(scope: string, form: typeof $createForm) {
    if (form.scopes.includes(scope)) {
      form.scopes = form.scopes.filter((s) => s !== scope);
    } else {
      form.scopes = [...form.scopes, scope];
    }
  }

  function formatDate(dateStr: string) {
    return new Date(dateStr).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  function generateCodeVerifier(): string {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return btoa(String.fromCharCode(...array))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }

  async function generateCodeChallenge(verifier: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);
    const digest = await crypto.subtle.digest("SHA-256", data);
    return btoa(String.fromCharCode(...new Uint8Array(digest)))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }

  async function testAuth(app: OAuthApp) {
    const params = new URLSearchParams({
      client_id: app.uid,
      redirect_uri: app.redirect_uri,
      response_type: "code",
      scope: app.scopes.join(" "),
    });

    if (!app.confidential) {
      const verifier = generateCodeVerifier();
      const challenge = await generateCodeChallenge(verifier);
      params.set("code_challenge", challenge);
      params.set("code_challenge_method", "S256");
      sessionStorage.setItem(`pkce_verifier_${app.uid}`, verifier);
    }

    window.location.href = `/oauth/authorize?${params.toString()}`;
  }
</script>

<PageLayout
  title="Developer Settings"
  icon={Code}
  iconColor="text-bright-purple"
  variant="narrow"
  {flash}
>
  <SectionCard class="overflow-hidden" bodyClass="p-0">
    <div class="grid grid-cols-3">
      <Link
        href={routes.settings.workspace(workspaceId)}
        class="px-4 py-2 text-sm font-medium text-fg-secondary hover:bg-bg-tertiary transition-colors duration-150 border-r border-bg-tertiary"
      >
        Workspace
      </Link>
      <Link
        href={routes.settings.billing(workspaceId)}
        class="px-4 py-2 text-sm font-medium text-fg-secondary hover:bg-bg-tertiary transition-colors duration-150 border-r border-bg-tertiary"
      >
        Billing
      </Link>
      <Link
        href={routes.settings.developer(workspaceId)}
        class="px-4 py-2 text-sm font-medium bg-bg-tertiary text-fg-primary"
        aria-current="page"
      >
        Developer
      </Link>
    </div>
  </SectionCard>

  <SectionCard title={`OAuth Applications (${applications.length})`} icon={Key}>
    {#snippet headerActions()}
      <Button
        tone="purple"
        size="sm"
        aria-label="Create new OAuth application"
        type="button"
        onclick={() => {
          $createForm.reset();
          showCreateModal = true;
        }}
      >
        <Plus class="w-4 h-4" aria-hidden="true" />
        New App
      </Button>
    {/snippet}

    {#if applications.length === 0}
      <EmptyState
        title="No OAuth applications"
        description="Create an OAuth application to allow third-party apps to access the Timevoice API on behalf of users."
        icon={Code}
      />
    {:else}
      <div
        class="divide-y divide-bg-tertiary"
        role="list"
        aria-label="OAuth applications"
      >
        {#each applications as app, i}
          {@const isLast = i === applications.length - 1}
          <div class="p-4 space-y-3 {isLast ? 'rounded-b-[10px]' : ''}">
            <div class="flex items-start justify-between gap-4">
              <div>
                <h4 class="font-medium text-fg-primary">{app.name}</h4>
                <p class="text-sm text-fg-muted mt-0.5">
                  Created {formatDate(app.created_at)}
                  {#if app.confidential}
                    <span
                      class="ml-2 px-1.5 py-0.5 text-xs bg-bright-blue/20 text-bright-blue rounded"
                      >Confidential</span
                    >
                  {:else}
                    <span
                      class="ml-2 px-1.5 py-0.5 text-xs bg-bright-purple/20 text-bright-purple rounded"
                      >Public (PKCE)</span
                    >
                  {/if}
                  {#if app.trust_level === "official"}
                    <span
                      class="ml-1 px-1.5 py-0.5 text-xs bg-bright-green/20 text-bright-green rounded"
                      >Official</span
                    >
                  {/if}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <IconButton
                  aria-label="Edit {app.name}"
                  onclick={() => openEditModal(app)}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="w-4 h-4"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                    />
                  </svg>
                </IconButton>
                <IconButton
                  aria-label="Regenerate secret for {app.name}"
                  onclick={() => openSecretModal(app)}
                >
                  <RefreshCw class="w-4 h-4" aria-hidden="true" />
                </IconButton>
                <IconButton
                  tone="danger"
                  aria-label="Delete {app.name}"
                  onclick={() => openDeleteModal(app)}
                >
                  <Trash2 class="w-4 h-4" aria-hidden="true" />
                </IconButton>
              </div>
            </div>

            <div class="grid gap-2 text-sm">
              <div class="flex items-center gap-2">
                <span class="text-fg-muted w-24 shrink-0">Client ID:</span>
                <code
                  class="flex-1 px-2 py-1 bg-bg-primary rounded font-mono text-xs truncate"
                  >{app.uid}</code
                >
                <IconButton
                  aria-label="Copy client ID"
                  onclick={() => copyToClipboard(app.uid, `uid-${app.id}`)}
                >
                  {#if copiedField === `uid-${app.id}`}
                    <Check
                      class="w-4 h-4 text-bright-green"
                      aria-hidden="true"
                    />
                  {:else}
                    <Copy class="w-4 h-4" aria-hidden="true" />
                  {/if}
                </IconButton>
              </div>

              <div class="flex items-center gap-2">
                <span class="text-fg-muted w-24 shrink-0">Client Secret:</span>
                {#if flash.new_secret && flash.secret_app_id === app.id}
                  <code
                    class="flex-1 px-2 py-1 bg-bg-primary rounded font-mono text-xs truncate"
                    >{flash.new_secret}</code
                  >
                  <IconButton
                    aria-label="Copy client secret"
                    onclick={() =>
                      copyToClipboard(flash.new_secret!, `secret-${app.id}`)}
                  >
                    {#if copiedField === `secret-${app.id}`}
                      <Check
                        class="w-4 h-4 text-bright-green"
                        aria-hidden="true"
                      />
                    {:else}
                      <Copy class="w-4 h-4" aria-hidden="true" />
                    {/if}
                  </IconButton>
                {:else}
                  <span class="flex-1 px-2 py-1 text-xs text-fg-muted italic"
                    >Only shown at creation</span
                  >
                {/if}
              </div>

              <div class="flex items-start gap-2">
                <span class="text-fg-muted w-24 shrink-0">Redirect URI:</span>
                <code
                  class="flex-1 px-2 py-1 bg-bg-primary rounded font-mono text-xs break-all"
                  >{app.redirect_uri}</code
                >
              </div>

              {#if app.scopes.length > 0}
                <div class="flex items-start gap-2">
                  <span class="text-fg-muted w-24 shrink-0">Scopes:</span>
                  <div class="flex flex-wrap gap-1">
                    {#each app.scopes as scope}
                      <span
                        class="px-2 py-0.5 text-xs bg-bright-purple/20 text-bright-purple rounded"
                        >{scope}</span
                      >
                    {/each}
                  </div>
                </div>
              {/if}

              <div class="flex items-center gap-2 pt-2">
                <button
                  type="button"
                  onclick={() => testAuth(app)}
                  class="inline-flex items-center gap-2 px-3 py-1.5 text-sm rounded-[10px] border transition-colors duration-150 bg-bg-primary border-bg-tertiary text-fg-secondary hover:bg-bg-tertiary hover:border-bright-purple"
                >
                  <Play class="w-4 h-4" aria-hidden="true" />
                  Test Auth
                </button>
              </div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </SectionCard>

  <SectionCard title="API Documentation" icon={ExternalLink}>
    <div class="p-4 space-y-3 text-sm text-fg-secondary">
      <p>
        View the full API documentation with interactive examples and code snippets.
      </p>
      <a
        href="/docs"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-[10px] bg-bright-purple text-white hover:bg-bright-purple/90 transition-colors"
      >
        <ExternalLink class="w-4 h-4" />
        Open API Reference
      </a>
      <div class="pt-2 border-t border-bg-tertiary mt-3">
        <p class="text-xs text-fg-muted">Quick reference:</p>
        <div class="mt-2 space-y-1">
          <code class="block px-2 py-1 bg-bg-primary rounded font-mono text-xs">
            Authorization: /oauth/authorize
          </code>
          <code class="block px-2 py-1 bg-bg-primary rounded font-mono text-xs">
            Token: /oauth/token
          </code>
          <code class="block px-2 py-1 bg-bg-primary rounded font-mono text-xs">
            API Base: /api/v1
          </code>
        </div>
      </div>
    </div>
  </SectionCard>

  <!-- Create Modal -->
  <Modal
    bind:open={showCreateModal}
    title="Create OAuth Application"
    maxWidth="max-w-lg"
    onclose={() => {
      showCreateModal = false;
      $createForm.reset();
    }}
  >
    <FormField id="app-name" label="Application Name" required>
      {#snippet children({ describedBy })}
        <TextInput
          id="app-name"
          tone="purple"
          bind:value={$createForm.name}
          placeholder="My Awesome App"
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>

    <FormField
      id="app-redirect"
      label="Redirect URI"
      description="The callback URL where users will be redirected after authorization."
      required
    >
      {#snippet children({ describedBy })}
        <TextInput
          id="app-redirect"
          tone="purple"
          bind:value={$createForm.redirect_uri}
          placeholder="https://myapp.com/oauth/callback"
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>

    <FormField
      id="app-confidential"
      label="Application Type"
      description="Confidential apps can keep secrets secure (server-side). Public apps use PKCE instead (mobile/SPA)."
    >
      {#snippet children({ describedBy })}
        <div class="space-y-2" role="group" aria-describedby={describedBy}>
          <label
            class="flex items-start gap-3 p-3 bg-bg-primary rounded-lg cursor-pointer hover:bg-bg-tertiary/50 transition-colors"
          >
            <input
              type="radio"
              name="create-confidential"
              checked={!$createForm.confidential}
              onchange={() => ($createForm.confidential = false)}
              class="mt-0.5 border-bg-tertiary text-bright-purple focus:ring-bright-purple focus:ring-offset-0 bg-bg-tertiary"
            />
            <div>
              <span class="font-medium text-fg-primary">Public (PKCE)</span>
              <p class="text-sm text-fg-muted mt-0.5">
                For mobile apps, SPAs, or CLI tools. Uses PKCE for security.
              </p>
            </div>
          </label>
          <label
            class="flex items-start gap-3 p-3 bg-bg-primary rounded-lg cursor-pointer hover:bg-bg-tertiary/50 transition-colors"
          >
            <input
              type="radio"
              name="create-confidential"
              checked={$createForm.confidential}
              onchange={() => ($createForm.confidential = true)}
              class="mt-0.5 border-bg-tertiary text-bright-purple focus:ring-bright-purple focus:ring-offset-0 bg-bg-tertiary"
            />
            <div>
              <span class="font-medium text-fg-primary">Confidential</span>
              <p class="text-sm text-fg-muted mt-0.5">
                For server-side apps that can securely store a client secret.
              </p>
            </div>
          </label>
        </div>
      {/snippet}
    </FormField>

    <FormField
      id="app-scopes"
      label="Scopes"
      description="Select the permissions your application needs."
    >
      {#snippet children({ describedBy })}
        <div class="space-y-2" role="group" aria-describedby={describedBy}>
          {#each Object.entries(scopes) as [scope, description]}
            <label
              class="flex items-start gap-3 p-3 bg-bg-primary rounded-lg cursor-pointer hover:bg-bg-tertiary/50 transition-colors"
            >
              <input
                type="checkbox"
                checked={$createForm.scopes.includes(scope)}
                onchange={() => toggleScope(scope, $createForm)}
                class="mt-0.5 rounded border-bg-tertiary text-bright-purple focus:ring-bright-purple focus:ring-offset-0 bg-bg-tertiary"
              />
              <div>
                <span class="font-medium text-fg-primary">{scope}</span>
                <p class="text-sm text-fg-muted mt-0.5">{description}</p>
              </div>
            </label>
          {/each}
        </div>
      {/snippet}
    </FormField>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          onclick={() => {
            showCreateModal = false;
            $createForm.reset();
          }}
          disabled={$createForm.processing}
        >
          Cancel
        </Button>
        <Button
          type="button"
          tone="purple"
          onclick={submitCreate}
          disabled={$createForm.processing ||
            !$createForm.name ||
            !$createForm.redirect_uri}
        >
          {$createForm.processing ? "Creating..." : "Create Application"}
        </Button>
      </div>
    {/snippet}
  </Modal>

  <!-- Edit Modal -->
  <Modal
    bind:open={showEditModal}
    title="Edit OAuth Application"
    maxWidth="max-w-lg"
    onclose={() => {
      showEditModal = false;
      selectedApp = null;
    }}
  >
    <FormField id="edit-app-name" label="Application Name" required>
      {#snippet children({ describedBy })}
        <TextInput
          id="edit-app-name"
          tone="purple"
          bind:value={$editForm.name}
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>

    <FormField
      id="edit-app-redirect"
      label="Redirect URI"
      description="The callback URL where users will be redirected after authorization."
      required
    >
      {#snippet children({ describedBy })}
        <TextInput
          id="edit-app-redirect"
          tone="purple"
          bind:value={$editForm.redirect_uri}
          aria-describedby={describedBy}
        />
      {/snippet}
    </FormField>

    <FormField
      id="edit-app-confidential"
      label="Application Type"
      description="Confidential apps can keep secrets secure (server-side). Public apps use PKCE instead (mobile/SPA)."
    >
      {#snippet children({ describedBy })}
        <div class="space-y-2" role="group" aria-describedby={describedBy}>
          <label
            class="flex items-start gap-3 p-3 bg-bg-primary rounded-lg cursor-pointer hover:bg-bg-tertiary/50 transition-colors"
          >
            <input
              type="radio"
              name="edit-confidential"
              checked={!$editForm.confidential}
              onchange={() => ($editForm.confidential = false)}
              class="mt-0.5 border-bg-tertiary text-bright-purple focus:ring-bright-purple focus:ring-offset-0 bg-bg-tertiary"
            />
            <div>
              <span class="font-medium text-fg-primary">Public (PKCE)</span>
              <p class="text-sm text-fg-muted mt-0.5">
                For mobile apps, SPAs, or CLI tools. Uses PKCE for security.
              </p>
            </div>
          </label>
          <label
            class="flex items-start gap-3 p-3 bg-bg-primary rounded-lg cursor-pointer hover:bg-bg-tertiary/50 transition-colors"
          >
            <input
              type="radio"
              name="edit-confidential"
              checked={$editForm.confidential}
              onchange={() => ($editForm.confidential = true)}
              class="mt-0.5 border-bg-tertiary text-bright-purple focus:ring-bright-purple focus:ring-offset-0 bg-bg-tertiary"
            />
            <div>
              <span class="font-medium text-fg-primary">Confidential</span>
              <p class="text-sm text-fg-muted mt-0.5">
                For server-side apps that can securely store a client secret.
              </p>
            </div>
          </label>
        </div>
      {/snippet}
    </FormField>

    <FormField
      id="edit-app-scopes"
      label="Scopes"
      description="Select the permissions your application needs."
    >
      {#snippet children({ describedBy })}
        <div class="space-y-2" role="group" aria-describedby={describedBy}>
          {#each Object.entries(scopes) as [scope, description]}
            <label
              class="flex items-start gap-3 p-3 bg-bg-primary rounded-lg cursor-pointer hover:bg-bg-tertiary/50 transition-colors"
            >
              <input
                type="checkbox"
                checked={$editForm.scopes.includes(scope)}
                onchange={() => toggleScope(scope, $editForm)}
                class="mt-0.5 rounded border-bg-tertiary text-bright-purple focus:ring-bright-purple focus:ring-offset-0 bg-bg-tertiary"
              />
              <div>
                <span class="font-medium text-fg-primary">{scope}</span>
                <p class="text-sm text-fg-muted mt-0.5">{description}</p>
              </div>
            </label>
          {/each}
        </div>
      {/snippet}
    </FormField>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          onclick={() => {
            showEditModal = false;
            selectedApp = null;
          }}
          disabled={$editForm.processing}
        >
          Cancel
        </Button>
        <Button
          type="button"
          tone="purple"
          onclick={submitEdit}
          disabled={$editForm.processing ||
            !$editForm.name ||
            !$editForm.redirect_uri}
        >
          {$editForm.processing ? "Saving..." : "Save Changes"}
        </Button>
      </div>
    {/snippet}
  </Modal>

  <ConfirmDeleteModal
    bind:open={showDeleteModal}
    title="Delete Application"
    itemName={selectedApp?.name || ""}
    warningMessage="This will revoke all access tokens and authorized grants. Users will need to re-authorize if you create a new application."
    onConfirm={confirmDelete}
    onClose={() => {
      showDeleteModal = false;
      selectedApp = null;
    }}
  />

  <!-- Regenerate Secret Modal -->
  <Modal
    bind:open={showSecretModal}
    title="Regenerate Client Secret"
    onclose={() => {
      showSecretModal = false;
      selectedApp = null;
    }}
  >
    <div class="space-y-4">
      <p class="text-fg-primary">
        Are you sure you want to regenerate the client secret for <span
          class="font-semibold">{selectedApp?.name}</span
        >?
      </p>
      <p class="text-sm text-fg-muted">
        The current secret will be invalidated immediately. You'll need to
        update your application with the new secret.
      </p>
    </div>

    {#snippet footer()}
      <div class="flex items-center justify-end gap-2">
        <Button
          type="button"
          variant="ghost"
          onclick={() => {
            showSecretModal = false;
            selectedApp = null;
          }}
        >
          Cancel
        </Button>
        <Button type="button" tone="purple" onclick={confirmRegenerateSecret}>
          Regenerate Secret
        </Button>
      </div>
    {/snippet}
  </Modal>
</PageLayout>
