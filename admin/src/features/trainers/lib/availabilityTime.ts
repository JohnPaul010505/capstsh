export function formatAvailability(entry: string): string {
  return entry.replace(/\b([01]?\d|2[0-3]):([0-5]\d)\b/g, (_, hour: string, minute: string) => {
    const value = Number(hour)
    return `${value % 12 || 12}:${minute} ${value < 12 ? 'AM' : 'PM'}`
  }).replace(/ (AM|PM)-/g, ' $1 – ')
}
