<script lang="ts">
  import {
    Clock,
    DollarSign,
    Folder,
    Hash,
    Paperclip,
    Trash2,
    X,
  } from "@lucide/svelte";
  import { page, router } from "@inertiajs/svelte";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Dialog from "$lib/components/ui/dialog/index.js";
  import * as Command from "$lib/components/ui/command/index.js";
  import { toast } from "svelte-sonner";
  import Button from "./Button.svelte";
  import DatePicker from "./DatePicker.svelte";
  import type { Project, Tag, TimeEntry } from "../types";
  import { formatFileSize, formatHours } from "../lib/format";
  import { routes } from "../lib/routes";
  import {
    draftFromEntry,
    toggleSelectedTag,
    type TimeEntryDraft,
  } from "../lib/time-entry-form";

  // The Google Calendar-style card for creating and editing an entry. With
  // no `entry` it creates one from `draft`; with one it updates that entry.
  // It pops out from `anchor`, or opens as a centred dialog when `modal`.
  interface Props {
    open: boolean;
    draft: TimeEntryDraft | null;
    entry?: TimeEntry | null;
    anchor?: HTMLElement | null;
    modal?: boolean;
    projects: Project[];
    tags: Tag[];
    minDay?: Date;
    maxDay?: Date;
    onClose: () => void;
    // Called once the card has finished fading out.
    onClosed?: () => void;
    onDelete?: (entry: TimeEntry) => void;
    onInteractOutside?: (event: PointerEvent) => void;
  }

  let {
    open,
    draft = $bindable(),
    entry = null,
    anchor = null,
    modal = false,
    projects,
    tags,
    minDay,
    maxDay,
    onClose,
    onClosed,
    onDelete,
    onInteractOutside,
  }: Props = $props();

  const workspaceId = $derived(page.props.auth?.workspace?.hashid);
  const label = $derived(entry ? "Edit time entry" : "New time entry");
  const DAY_MINUTES = 24 * 60;
  const MAX_FILES = 3;

  let descriptionInput: HTMLTextAreaElement | null = $state(null);
  let fileInput: HTMLInputElement | null = $state(null);
  let showProjectPicker = $state(false);
  let showTagPicker = $state(false);
  let files = $state<File[]>([]);
  let saving = $state(false);

  // A running entry has no end yet; it stops from the timer, not from here.
  let running = $derived(!!entry && !entry.end_at);
  let attachedCount = $derived((entry?.files?.length ?? 0) + files.length);
  let selectedProject = $derived(
    projects.find((p) => p.id === draft?.project_id),
  );
  let selectedTags = $derived(
    tags.filter((t) => draft?.tag_ids.includes(t.id)),
  );

  // Reset on open rather than close, so nothing changes while it fades out.
  $effect(() => {
    if (open) {
      files = [];
      showProjectPicker = showTagPicker = false;
    }
  });

  const pad = (n: number) => String(n).padStart(2, "0");
  const timeOfDay = (minute: number) =>
    `${pad(Math.floor(minute / 60) % 24)}:${pad(minute % 60)}`;
  const parseTime = (value: string) => {
    const [hours, minutes] = value.split(":").map(Number);
    return hours * 60 + minutes;
  };

  // A new start time keeps the entry's length, like Google Calendar.
  function setStart(value: string) {
    if (!value || !draft) return;
    const length = draft.to - draft.from;
    draft.from = parseTime(value);
    draft.to = draft.from + length;
  }

  // An end time at or before the start means the entry ran past midnight.
  function setEnd(value: string) {
    if (!value || !draft) return;
    const to = parseTime(value);
    draft.to = to <= draft.from ? to + DAY_MINUTES : to;
  }

  function selectProject(project: Project | null) {
    if (!draft) return;
    draft.project_id = project?.id ?? null;
    if (project?.billable_default) draft.billable = true;
    showProjectPicker = false;
  }

  function addFiles(event: Event & { currentTarget: HTMLInputElement }) {
    const picked = Array.from(event.currentTarget.files ?? []);
    event.currentTarget.value = "";
    if (attachedCount + picked.length > MAX_FILES) {
      toast.error(`You can only attach up to ${MAX_FILES} files`);
      return;
    }
    files = [...files, ...picked];
  }

  function removeAttachedFile(blobId: number) {
    if (!entry) return;
    router.delete(
      `${routes.timeEntries.removeFile(workspaceId, entry.id)}?blob_id=${blobId}`,
      { preserveScroll: true, preserveState: true },
    );
  }

  function save() {
    if (!draft || !draft.description.trim() || saving) return;
    const { day, from, to, ...fields } = draft;
    const at = (minute: number) => {
      const date = new Date(day);
      date.setHours(0, minute, 0, 0);
      return date.toISOString();
    };
    // Untouched times are left out, so saving an edit keeps their seconds.
    const original = entry && draftFromEntry(entry);
    const moved =
      !running &&
      (!original ||
        original.day.getTime() !== day.getTime() ||
        original.from !== from ||
        original.to !== to);
    const time_entry = {
      ...fields,
      // An edit sends [""] to clear every tag; an empty list leaves them.
      tag_ids: entry && !fields.tag_ids.length ? [""] : fields.tag_ids,
      ...(moved && { start_at: at(from), end_at: at(to) }),
      ...(files.length && { files }),
    };
    const options = {
      preserveScroll: true,
      preserveState: true,
      onStart: () => (saving = true),
      onFinish: () => (saving = false),
      onSuccess: onClose,
    };
    if (entry) {
      router.patch(
        routes.timeEntries.update(workspaceId, entry.id),
        { time_entry },
        options,
      );
    } else {
      router.post(
        routes.timeEntries.create(workspaceId),
        { time_entry },
        options,
      );
    }
  }

  function remove() {
    if (!entry) return;
    onClose();
    onDelete?.(entry);
  }

  const row =
    "flex items-center gap-3 w-full min-h-9 -mx-2 px-2 rounded-lg text-left transition-colors duration-150";
  const rowButton = `${row} hover:bg-bg-tertiary data-[state=open]:bg-bg-tertiary`;
  const timeField =
    "bg-transparent text-fg-primary font-tabular h-8 px-1.5 rounded-lg hover:bg-bg-tertiary focus:bg-bg-tertiary outline-none transition-colors duration-150 [&::-webkit-calendar-picker-indicator]:hidden";
  const card = "w-[26rem] max-w-[calc(100vw-1.5rem)] gap-0 p-0 shadow-2xl";
  const headerButton =
    "inline-flex items-center justify-center size-8 rounded-lg text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors duration-150";
</script>

{#snippet body()}
  {#if draft}
    {@const d = draft}
    <div class="flex items-center gap-0.5 pl-4 pr-2 pt-2">
      <span class="mr-auto text-xs font-medium text-fg-muted">{label}</span>
      {#if entry && onDelete}
        <button
          type="button"
          class="{headerButton} hover:text-bright-red hover:bg-bright-red/10"
          aria-label="Delete entry"
          title="Delete entry"
          onclick={remove}
        >
          <Trash2 class="size-4" aria-hidden="true" />
        </button>
      {/if}
      <button
        type="button"
        class={headerButton}
        aria-label="Close"
        onclick={onClose}
      >
        <X class="size-4" aria-hidden="true" />
      </button>
    </div>

    <div class="px-4 pb-4 space-y-3">
      <!-- Wraps to show the whole description, but stays one line of text: Enter saves. -->
      <textarea
        bind:this={descriptionInput}
        bind:value={d.description}
        id="quick-entry-description"
        rows="1"
        aria-label="Description"
        placeholder="What did you work on?"
        autocomplete="off"
        class="block w-full py-2 field-sizing-content resize-none bg-transparent border-b-2 border-bg-tertiary focus:border-bright-purple text-xl font-semibold text-fg-primary placeholder:font-medium placeholder:text-fg-dim outline-none transition-colors duration-150"
        oninput={(e) => {
          const value = e.currentTarget.value;
          if (value.includes("\n"))
            d.description = value.replace(/\s*\n\s*/g, " ");
        }}
        onkeydown={(e) => {
          if (e.key !== "Enter" || e.isComposing) return;
          e.preventDefault();
          save();
        }}></textarea>

      <div>
        <div class="{row} items-start pb-1">
          <Clock
            class="size-4 shrink-0 mt-2 text-fg-muted"
            aria-hidden="true"
          />
          <div class="min-w-0 -ml-1.5">
            <div class="flex flex-wrap items-center gap-x-1">
              <DatePicker
                id="quick-entry-date"
                bind:value={() => d.day, (date) => date && (d.day = date)}
                min={minDay}
                max={maxDay}
                format={(date) =>
                  date.toLocaleDateString("en-US", {
                    weekday: "long",
                    month: "short",
                    day: "numeric",
                  })}
                class="w-auto h-8 gap-1.5 px-1.5 rounded-lg border-transparent bg-transparent hover:bg-bg-tertiary hover:border-transparent data-[state=open]:border-transparent data-[state=open]:bg-bg-tertiary [&>svg]:hidden"
              />
              {#if running}
                <span class="px-1.5 text-fg-muted font-tabular"
                  >{timeOfDay(d.from)} – now</span
                >
              {:else}
                <div class="flex items-center gap-0.5">
                  <input
                    type="time"
                    aria-label="Start time"
                    value={timeOfDay(d.from)}
                    oninput={(e) => setStart(e.currentTarget.value)}
                    class={timeField}
                  />
                  <span class="text-fg-dim" aria-hidden="true">–</span>
                  <input
                    type="time"
                    aria-label="End time"
                    value={timeOfDay(d.to)}
                    oninput={(e) => setEnd(e.currentTarget.value)}
                    class={timeField}
                  />
                </div>
              {/if}
            </div>
            <p class="px-1.5 text-xs text-fg-muted font-tabular">
              <span class="font-medium text-bright-purple"
                >{running ? "Running" : formatHours((d.to - d.from) * 60)}</span
              >{!running && d.to > DAY_MINUTES ? " · Ends the next day" : ""}
            </p>
          </div>
        </div>

        {#if projects.length > 0}
          <Popover.Root bind:open={showProjectPicker}>
            <Popover.Trigger class={rowButton}>
              {#if selectedProject}
                <span
                  class="grid place-items-center size-4 shrink-0"
                  aria-hidden="true"
                >
                  <span
                    class="size-2.5 rounded-full"
                    style="background-color: {selectedProject.color}"
                  ></span>
                </span>
                <span class="truncate text-fg-primary"
                  >{selectedProject.name}</span
                >
                {#if selectedProject.client}
                  <span class="truncate text-fg-muted"
                    >· {selectedProject.client.name}</span
                  >
                {/if}
              {:else}
                <Folder
                  class="size-4 shrink-0 text-fg-muted"
                  aria-hidden="true"
                />
                <span class="text-fg-muted">Add project</span>
              {/if}
            </Popover.Trigger>
            <Popover.Content align="start" class="w-64 p-0">
              <Command.Root>
                <Command.Input placeholder="Search projects..." />
                <Command.List>
                  <Command.Empty>No matching projects.</Command.Empty>
                  {#if selectedProject}
                    <Command.Item
                      value="No project"
                      onSelect={() => selectProject(null)}
                      class="gap-3 px-3 py-2 rounded-[5px] text-fg-muted"
                    >
                      <X class="w-3 h-3" aria-hidden="true" />
                      No project
                    </Command.Item>
                  {/if}
                  {#each projects as project (project.id)}
                    <Command.Item
                      value={`${project.name} ${project.client?.name ?? ""}`}
                      data-checked={d.project_id === project.id}
                      onSelect={() => selectProject(project)}
                      class="gap-3 px-3 py-2 rounded-[5px]"
                    >
                      <span
                        class="w-3 h-3 rounded-full shrink-0"
                        style="background-color: {project.color}"
                        aria-hidden="true"
                      ></span>
                      <div class="flex-1 min-w-0">
                        <p class="text-fg-primary truncate">
                          {project.name}
                        </p>
                        {#if project.client}
                          <p class="text-xs text-fg-muted truncate">
                            {project.client.name}
                          </p>
                        {/if}
                      </div>
                    </Command.Item>
                  {/each}
                </Command.List>
              </Command.Root>
            </Popover.Content>
          </Popover.Root>
        {/if}

        {#if tags.length > 0}
          <Popover.Root bind:open={showTagPicker}>
            <Popover.Trigger class={rowButton}>
              <Hash class="size-4 shrink-0 text-fg-muted" aria-hidden="true" />
              {#if selectedTags.length > 0}
                <span class="flex flex-wrap gap-1 py-1.5">
                  {#each selectedTags as tag (tag.id)}
                    <span
                      class="px-1.5 py-0.5 rounded-md bg-bg-tertiary text-xs font-medium text-fg-primary"
                      >{tag.name}</span
                    >
                  {/each}
                </span>
              {:else}
                <span class="text-fg-muted">Add tags</span>
              {/if}
            </Popover.Trigger>
            <Popover.Content align="start" class="w-56 p-0">
              <Command.Root>
                <Command.Input placeholder="Search tags..." />
                <Command.List>
                  <Command.Empty>No matching tags.</Command.Empty>
                  {#each tags as tag (tag.id)}
                    <Command.Item
                      value={tag.name}
                      data-checked={d.tag_ids.includes(tag.id)}
                      onSelect={() =>
                        (d.tag_ids = toggleSelectedTag(d.tag_ids, tag.id))}
                      class="px-3 py-2 rounded-[5px]"
                    >
                      <span class="text-fg-primary">{tag.name}</span>
                    </Command.Item>
                  {/each}
                </Command.List>
              </Command.Root>
            </Popover.Content>
          </Popover.Root>
        {/if}

        <button
          type="button"
          class={rowButton}
          role="switch"
          aria-checked={d.billable}
          onclick={() => (d.billable = !d.billable)}
        >
          <DollarSign
            class="size-4 shrink-0 {d.billable
              ? 'text-bright-green'
              : 'text-fg-muted'}"
            aria-hidden="true"
          />
          <span class={d.billable ? "text-bright-green" : "text-fg-muted"}
            >{d.billable ? "Billable" : "Non-billable"}</span
          >
          <span
            class="ml-auto flex items-center w-8 h-[18px] p-0.5 rounded-full transition-colors duration-150 {d.billable
              ? 'bg-bright-green'
              : 'bg-bg-quaternary'}"
            aria-hidden="true"
          >
            <span
              class="size-3.5 rounded-full bg-bg-primary transition-transform duration-150 {d.billable
                ? 'translate-x-3.5'
                : ''}"
            ></span>
          </span>
        </button>

        <div class="{row} items-start">
          <Paperclip
            class="size-4 shrink-0 mt-2.5 text-fg-muted"
            aria-hidden="true"
          />
          <div class="flex flex-wrap items-center gap-1 min-w-0 py-1">
            {#each entry?.files ?? [] as file (file.blob_id)}
              <span
                class="inline-flex items-center gap-1 h-7 pl-2 pr-0.5 rounded-md bg-bg-tertiary text-xs font-medium"
              >
                <span class="truncate max-w-32">{file.filename}</span>
                <span class="text-fg-muted"
                  >{formatFileSize(file.byte_size)}</span
                >
                <button
                  type="button"
                  class="grid place-items-center size-6 rounded text-fg-muted hover:text-bright-red transition-colors"
                  aria-label="Delete {file.filename}"
                  onclick={() => removeAttachedFile(file.blob_id)}
                >
                  <X class="size-3" aria-hidden="true" />
                </button>
              </span>
            {/each}
            {#each files as file, index (file)}
              <span
                class="inline-flex items-center gap-1 h-7 pl-2 pr-0.5 rounded-md border border-dashed border-bright-blue/60 text-xs font-medium"
              >
                <span class="truncate max-w-32">{file.name}</span>
                <span class="text-fg-muted">{formatFileSize(file.size)}</span>
                <button
                  type="button"
                  class="grid place-items-center size-6 rounded text-fg-muted hover:text-bright-red transition-colors"
                  aria-label="Remove {file.name}"
                  onclick={() => (files = files.filter((_, i) => i !== index))}
                >
                  <X class="size-3" aria-hidden="true" />
                </button>
              </span>
            {/each}
            {#if attachedCount < MAX_FILES}
              <input
                bind:this={fileInput}
                type="file"
                multiple
                class="hidden"
                onchange={addFiles}
              />
              <button
                type="button"
                class="h-7 px-1.5 {attachedCount
                  ? ''
                  : '-ml-1.5'} rounded-md text-fg-muted hover:text-fg-primary hover:bg-bg-tertiary transition-colors duration-150"
                onclick={() => fileInput?.click()}
              >
                {attachedCount ? "Add" : "Add attachments"}
              </button>
            {/if}
          </div>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-end gap-2 px-4 pb-4">
      <Button type="button" variant="ghost" onclick={onClose}>Cancel</Button>
      <Button
        type="button"
        tone="purple"
        onclick={save}
        disabled={!d.description.trim() || saving}
      >
        Save
      </Button>
    </div>
  {/if}
{/snippet}

{#if modal}
  <Dialog.Root
    {open}
    onOpenChange={(isOpen) => !isOpen && onClose()}
    onOpenChangeComplete={(isOpen) => !isOpen && onClosed?.()}
  >
    <Dialog.Content
      showCloseButton={false}
      class={card}
      aria-label={label}
      onOpenAutoFocus={(e) => {
        e.preventDefault();
        descriptionInput?.focus();
      }}
    >
      {@render body()}
    </Dialog.Content>
  </Dialog.Root>
{:else}
  <Popover.Root
    {open}
    onOpenChange={(isOpen) => !isOpen && onClose()}
    onOpenChangeComplete={(isOpen) => !isOpen && onClosed?.()}
  >
    <Popover.Content
      customAnchor={anchor}
      side="right"
      align="start"
      sideOffset={10}
      collisionPadding={12}
      updatePositionStrategy="always"
      class={card}
      aria-label={label}
      onOpenAutoFocus={(e) => {
        e.preventDefault();
        descriptionInput?.focus();
      }}
      onCloseAutoFocus={(e) => e.preventDefault()}
      {onInteractOutside}
    >
      {@render body()}
    </Popover.Content>
  </Popover.Root>
{/if}
