<script lang="ts">
  import TimerInput from "../../components/TimerInput.svelte";
  import WeekCalendar from "../../components/WeekCalendar.svelte";
  import { page } from "@inertiajs/svelte";
</script>

<TimerInput
  runningEntry={$page.props.runningEntry}
  projects={$page.props.projects || []}
  tags={$page.props.tags || []}
/>

<div class="flex-1 overflow-hidden">
  <WeekCalendar
    entries={$page.props.entries || []}
    projects={$page.props.projects || []}
    currentWeek={$page.props.currentWeek || { start: "", end: "" }}
  />
</div>
