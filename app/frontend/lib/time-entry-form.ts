import type { TimeEntry } from "../types";

export function toggleSelectedTag(tagIds: number[], tagId: number) {
  return tagIds.includes(tagId)
    ? tagIds.filter((id) => id !== tagId)
    : [...tagIds, tagId];
}

// What the entry popover edits. Times are minutes from the start of `day`
// and `to` can pass 24:00 for an entry that ends the next day.
export type TimeEntryDraft = {
  day: Date;
  from: number;
  to: number;
  description: string;
  project_id: number | null;
  tag_ids: number[];
  billable: boolean;
};

export function draftFromEntry(entry: TimeEntry): TimeEntryDraft {
  const start = new Date(entry.start_at);
  const end = entry.end_at ? new Date(entry.end_at) : new Date();
  const day = new Date(start);
  day.setHours(0, 0, 0, 0);
  const from = start.getHours() * 60 + start.getMinutes();
  return {
    day,
    from,
    to: from + Math.round((end.getTime() - start.getTime()) / 60_000),
    description: entry.description ?? "",
    project_id: entry.project?.id ?? null,
    tag_ids: entry.tags.map((t) => t.id),
    billable: !!entry.billable,
  };
}
