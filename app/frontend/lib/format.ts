/**
 * Shared formatting utilities
 */

export function formatRate(cents: number): string {
  return (cents / 100).toFixed(2);
}

export function parseRate(value: string): number {
  const num = parseFloat(value);
  return Number.isFinite(num) ? Math.round(num * 100) : 0;
}

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
  return new Date(timestamp).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
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
  const date = new Date(dateString);
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

/**
 * Format a time to 12-hour format (e.g., "02:30 PM")
 */
export function formatTime(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleTimeString("en-US", {
    hour: "2-digit",
    minute: "2-digit",
  });
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
