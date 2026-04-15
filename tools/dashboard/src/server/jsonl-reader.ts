interface ReadOptions {
  from?: string;
  to?: string;
  eventType?: string;
  maxLines?: number;
}

export async function readJsonl(
  filePath: string,
  opts: ReadOptions = {},
): Promise<Record<string, unknown>[]> {
  const file = Bun.file(filePath);
  if (!(await file.exists())) return [];

  const text = await file.text();
  const lines = text.split('\n').filter((line) => line.trim().length > 0);

  const maxLines = opts.maxLines ?? 10000;
  const recent = lines.slice(-maxLines);

  const entries: Record<string, unknown>[] = [];

  for (const line of recent) {
    try {
      const entry = JSON.parse(line) as Record<string, unknown>;

      if (opts.from && typeof entry.timestamp === 'string') {
        if (entry.timestamp < opts.from) continue;
      }
      if (opts.to && typeof entry.timestamp === 'string') {
        if (entry.timestamp > opts.to) continue;
      }
      if (
        opts.eventType &&
        typeof entry.event_type === 'string' &&
        entry.event_type !== opts.eventType
      ) {
        continue;
      }

      entries.push(entry);
    } catch {
      // Skip malformed lines
    }
  }

  return entries;
}
