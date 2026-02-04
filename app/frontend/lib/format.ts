/**
 * Shared formatting utilities
 */

export function formatRate(cents: number): string {
  return (cents / 100).toFixed(2)
}

export function parseRate(value: string): number {
  const num = parseFloat(value)
  return Number.isFinite(num) ? Math.round(num * 100) : 0
}

export function formatDate(dateStr: string): string {
  return new Date(`${dateStr}T00:00:00`).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  })
}

export function getStatusColor(status: string): string {
  switch (status) {
    case 'draft':
      return 'text-fg-muted'
    case 'issued':
      return 'text-bright-blue'
    case 'paid':
      return 'text-bright-green'
    default:
      return 'text-fg-muted'
  }
}

export function getStatusBg(status: string): string {
  switch (status) {
    case 'draft':
      return 'bg-bg-tertiary'
    case 'issued':
      return 'bg-bright-blue/20'
    case 'paid':
      return 'bg-bright-green/20'
    default:
      return 'bg-bg-tertiary'
  }
}

export function getStatusClasses(status: string): string {
  switch (status) {
    case 'draft':
      return 'text-fg-muted bg-bg-tertiary'
    case 'issued':
      return 'text-bright-blue bg-bright-blue/20'
    case 'paid':
      return 'text-bright-green bg-bright-green/20'
    default:
      return 'text-fg-muted bg-bg-tertiary'
  }
}

/**
 * Format a date to YYYY-MM-DD string
 */
export function toDateString(date: Date): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * Set a date range relative to today
 */
export function getRelativeDateRange(daysBack: number): { start: Date; end: Date } {
  const end = new Date()
  end.setHours(0, 0, 0, 0)
  const start = new Date(end)
  start.setDate(end.getDate() - daysBack)
  return { start, end }
}

/**
 * Set a date range for the last month
 */
export function getLastMonthRange(): { start: Date; end: Date } {
  const end = new Date()
  end.setHours(0, 0, 0, 0)
  const start = new Date(end)
  start.setMonth(end.getMonth() - 1)
  return { start, end }
}

/**
 * Format a date to short format (e.g., "Jan 15")
 */
export function formatShortDate(dateString: string): string {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

/**
 * Format a time to 12-hour format (e.g., "02:30 PM")
 */
export function formatTime(dateString: string): string {
  const date = new Date(dateString)
  return date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit'
  })
}

/**
 * Format bytes to human readable format (e.g., "1.5 MB")
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}
