function pad(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function formatDateTime(millis: number): string {
  const date = new Date(millis);
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function formatShortDate(millis: number): string {
  const date = new Date(millis);
  return `${date.getMonth() + 1}月${date.getDate()}日 ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
