/**
 * Shared formatting utilities
 */

import { page } from "@inertiajs/svelte";

export function formatRate(cents: number): string {
  return (cents / 100).toFixed(2);
}

export function parseRate(value: string): number {
  const num = parseFloat(value);
  return Number.isFinite(num) ? Math.round(num * 100) : 0;
}

// Matches the server: invoice lines store hours rounded half up to two
// decimals, then round the amount half up. Working in whole hundredths keeps
// 0.57 × 2550 at 1454, and toPrecision turns 1.005 × 100 = 100.49999… back
// into 100.5 so it rounds to 1.01 hours like the server.
export function lineAmountCents(hours: number, rateCents: number): number {
  const hundredths = Math.round(Number((hours * 100).toPrecision(15)));
  return Math.round((hundredths * rateCents) / 100);
}

// toLocaleDateString builds a new Intl formatter on every call (~0.1 ms), which
// adds up to hundreds of milliseconds on long lists, so reuse one per format.
export function dateFormatter(
  options: Intl.DateTimeFormatOptions,
): (date: Date) => string {
  const formatter = new Intl.DateTimeFormat("en-US", options);
  return (date) =>
    Number.isNaN(date.getTime()) ? "Invalid Date" : formatter.format(date);
}

const longDate = dateFormatter({
  month: "short",
  day: "numeric",
  year: "numeric",
});
const shortDate = dateFormatter({ month: "short", day: "numeric" });
const clock12 = dateFormatter({ hour: "numeric", minute: "2-digit" });
const clock24 = dateFormatter({
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

/**
 * Parse a YYYY-MM-DD date as local midnight (not UTC, which can shift the day)
 */
export function parseLocalDate(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00`);
}

/**
 * Format a YYYY-MM-DD date (e.g., "Nov 4, 2026")
 */
export function formatDate(dateStr: string): string {
  return formatTimestamp(parseLocalDate(dateStr));
}

/**
 * Format an ISO timestamp or Date as a local date (e.g., "Nov 4, 2026")
 */
export function formatTimestamp(timestamp: string | Date): string {
  return longDate(new Date(timestamp));
}

/**
 * Format cents as US dollars (e.g., "$1,234.50")
 */
export function formatCurrency(cents: number): string {
  return (cents / 100).toLocaleString("en-US", {
    style: "currency",
    currency: "USD",
  });
}

const STATUS_CLASSES: Record<string, string> = {
  draft: "text-fg-muted bg-bg-tertiary",
  issued: "text-bright-blue bg-bright-blue/20",
  paid: "text-bright-green bg-bright-green/20",
};

/**
 * Text and background classes for an invoice status
 */
export function getStatusClasses(status: string): string {
  return STATUS_CLASSES[status] ?? STATUS_CLASSES.draft;
}

/**
 * Format a date to YYYY-MM-DD string
 */
export function toDateString(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Set a date range relative to today
 */
export function getRelativeDateRange(daysBack: number): {
  start: Date;
  end: Date;
} {
  const end = new Date();
  end.setHours(0, 0, 0, 0);
  const start = new Date(end);
  start.setDate(end.getDate() - daysBack);
  return { start, end };
}

/**
 * The previous calendar month (e.g. Oct 1 – Oct 31 when today is in November)
 */
export function getLastMonthRange(): { start: Date; end: Date } {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const end = new Date(now.getFullYear(), now.getMonth(), 0);
  return { start, end };
}

/**
 * Format a date to short format (e.g., "Jan 15")
 */
export function formatShortDate(dateString: string | Date): string {
  return shortDate(new Date(dateString));
}

/**
 * Whether the signed-in user picked the 24-hour clock in Settings. Reads
 * reactive page props, so templates re-render when the choice changes.
 */
export function uses24HourClock(): boolean {
  return page.props.auth?.user?.use_24_hour_clock === true;
}

/**
 * Format a time of day in the user's clock (e.g., "2:30 PM" or "14:30")
 */
export function formatTime(time: string | Date): string {
  return (uses24HourClock() ? clock24 : clock12)(new Date(time));
}

/**
 * Format seconds as H:MM:SS (e.g., "0:30:00")
 */
export function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  return `${hours}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
}

/**
 * Format seconds as compact hours and minutes (e.g., "1h", "6h 15m", "45m")
 */
export function formatHours(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (seconds > 0 && seconds < 60) return "<1m";
  if (hours && minutes) return `${hours}h ${minutes}m`;
  return hours || !minutes ? `${hours}h` : `${minutes}m`;
}

/**
 * Parse a typed duration ("1h 30m", "90m", "1:30", "45") into seconds.
 * A bare number means minutes. Returns null for anything else.
 */
export function parseDuration(text: string): number | null {
  const value = text.trim().toLowerCase();
  const clock = value.match(/^(\d+):([0-5]\d)$/);
  if (clock) return Number(clock[1]) * 3600 + Number(clock[2]) * 60;
  if (/^\d+$/.test(value)) return Number(value) * 60;
  const units = value.match(/^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?$/);
  if (!units || (!units[1] && !units[2])) return null;
  return Number(units[1] ?? 0) * 3600 + Number(units[2] ?? 0) * 60;
}

/**
 * Format bytes to human readable format (e.g., "1.5 MB")
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return "0 Bytes";
  const k = 1024;
  const sizes = ["Bytes", "KB", "MB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
}
