<script lang="ts">
  import { CalendarDate, type DateValue } from "@internationalized/date";
  import { CalendarDays } from "lucide-svelte";
  import { Calendar } from "$lib/components/ui/calendar/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import { toDateString } from "../lib/format";
  import { cn } from "$lib/utils.js";

  interface Props {
    id?: string;
    value: Date | null;
    min?: Date | null;
    max?: Date | null;
    placeholder?: string;
    class?: string;
    format?: (date: Date) => string;
    "aria-describedby"?: string;
  }

  let {
    id,
    value = $bindable(),
    min = null,
    max = null,
    placeholder = "Select date",
    class: className = "",
    format = toDateString,
    "aria-describedby": describedBy,
  }: Props = $props();

  let open = $state(false);

  const toCalendarDate = (date: Date | null) =>
    date
      ? new CalendarDate(
          date.getFullYear(),
          date.getMonth() + 1,
          date.getDate(),
        )
      : undefined;

  let calendarValue = $derived(toCalendarDate(value));

  function select(date: DateValue | undefined) {
    if (!date) return;
    value = new Date(date.year, date.month - 1, date.day);
    open = false;
  }
</script>

<Popover.Root bind:open>
  <Popover.Trigger
    {id}
    aria-describedby={describedBy}
    class={cn(
      "w-full flex items-center justify-between gap-2 px-4 py-2 rounded-[10px] border border-bg-tertiary bg-bg-primary text-left transition-colors duration-150 hover:border-bg-quaternary data-[state=open]:border-bright-blue",
      className,
    )}
  >
    <span class={value ? "text-fg-primary" : "text-fg-dim"}>
      {value ? format(value) : placeholder}
    </span>
    <CalendarDays class="w-4 h-4 text-fg-muted" aria-hidden="true" />
  </Popover.Trigger>
  <Popover.Content align="start" class="w-auto p-0">
    <Calendar
      type="single"
      value={calendarValue}
      onValueChange={select}
      minValue={toCalendarDate(min)}
      maxValue={toCalendarDate(max)}
      captionLayout="dropdown"
    />
  </Popover.Content>
</Popover.Root>
