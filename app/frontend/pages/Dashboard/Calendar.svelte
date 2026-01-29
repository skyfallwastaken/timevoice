<script lang="ts">
  import AppShell from '../../components/AppShell.svelte'
  import TimerInput from '../../components/TimerInput.svelte'
  import WeekCalendar from '../../components/WeekCalendar.svelte'
  import { page } from '@inertiajs/svelte'

  let entries = $derived($page.props.entries || [])
  let currentWeek = $derived($page.props.currentWeek || { start: '', end: '' })
  let projects = $derived($page.props.projects || [])
  let tags = $derived($page.props.tags || [])
  let runningEntry = $derived($page.props.runningEntry)
</script>

<AppShell>
  <TimerInput {runningEntry} {projects} {tags} />

  <div class="flex-1 overflow-hidden">
    <WeekCalendar {entries} {projects} {currentWeek} />
  </div>
</AppShell>
