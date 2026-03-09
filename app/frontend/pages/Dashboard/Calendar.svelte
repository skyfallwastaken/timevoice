<script lang="ts">
  import TimerInput from "../../components/TimerInput.svelte";
  import WeekCalendar from "../../components/WeekCalendar.svelte";
  import TimeEntryEditModal from "../../components/TimeEntryEditModal.svelte";
  import { page } from "@inertiajs/svelte";
  import type { TimeEntry, Project, Tag } from "../../types";

  let selectedEntry = $state<TimeEntry | null>(null);
  let showEditModal = $state(false);

  function handleEntryClick(entry: TimeEntry) {
    selectedEntry = entry;
    showEditModal = true;
  }

  function closeEditModal() {
    showEditModal = false;
    selectedEntry = null;
  }
</script>

<TimerInput
  runningEntry={$page.props.runningEntry}
  projects={($page.props.projects as Project[]) || []}
  tags={($page.props.tags as Tag[]) || []}
/>

<div class="flex-1 overflow-hidden">
  <WeekCalendar
    entries={($page.props.entries as TimeEntry[]) || []}
    projects={($page.props.projects as Project[]) || []}
    tags={($page.props.tags as Tag[]) || []}
    currentWeek={$page.props.currentWeek || { start: "", end: "" }}
    onEntryClick={handleEntryClick}
  />
</div>

<TimeEntryEditModal
  entry={selectedEntry}
  projects={($page.props.projects as Project[]) || []}
  tags={($page.props.tags as Tag[]) || []}
  open={showEditModal}
  onClose={closeEditModal}
/>
