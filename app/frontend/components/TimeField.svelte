<script lang="ts">
  import { TimeField } from "bits-ui";
  import { Time } from "@internationalized/date";
  import { tick } from "svelte";
  import { uses24HourClock } from "../lib/format";

  // A native time input follows the browser's locale, not the user's clock
  // setting, so this edits an "HH:MM" string in either clock. Like a native
  // input, the value is "" while a segment is cleared.
  interface Props {
    value: string;
    label: string;
    class?: string;
  }

  let { value = $bindable(), label, class: className = "" }: Props = $props();

  const pad = (n: number) => String(n).padStart(2, "0");
  const toText = (time: Time) => `${pad(time.hour)}:${pad(time.minute)}`;
  const toTime = (text: string) => {
    const [hours, minutes] = text.split(":").map(Number);
    return new Time(hours, minutes);
  };

  // Replacing the field's value mid-typing resets it, so "1" then "6" would
  // land in two segments; only replace it when the time really changed.
  // While a segment is cleared, any value from outside (such as manual entry
  // resetting after Add) must refill the field, even the same time.
  let time = $state(toTime(value));
  let cleared = false;
  $effect.pre(() => {
    if (!value || (!cleared && value === toText(time))) return;
    cleared = false;
    time = toTime(value);
  });

  // bits-ui only reports a value once every segment is filled, so watch for a
  // segment cleared with Backspace or Delete.
  async function syncCleared(event: { currentTarget: HTMLElement }) {
    const field = event.currentTarget;
    await tick();
    if (!field.querySelector('[aria-valuetext="Empty"]')) return;
    cleared = true;
    value = "";
  }
</script>

<TimeField.Root
  value={time}
  onValueChange={(next) => {
    if (!next) return;
    cleared = false;
    time = next;
    value = toText(next);
  }}
  hourCycle={uses24HourClock() ? 24 : 12}
  granularity="minute"
  locale="en-US"
>
  <TimeField.Input
    aria-label={label}
    onkeydown={syncCleared}
    class="inline-flex items-center h-8 px-1.5 rounded-lg text-fg-primary font-tabular whitespace-nowrap hover:bg-bg-tertiary focus-within:bg-bg-tertiary transition-colors duration-150 {className}"
  >
    {#snippet children({ segments })}
      {#each segments as segment, index (index)}
        <TimeField.Segment
          part={segment.part}
          class={segment.part === "literal"
            ? "text-fg-muted"
            : "rounded-[4px] px-px outline-none focus:bg-bright-purple/30"}
          >{segment.value}</TimeField.Segment
        >
      {/each}
    {/snippet}
  </TimeField.Input>
</TimeField.Root>
